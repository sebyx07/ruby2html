# frozen_string_literal: true

require 'json'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'tmpdir'
require 'yaml'

# Coverage guard for the dependency audits in CI.
#
# The matrix jobs install an unlocked gemfile: ruby/setup-ruby resolves it
# during the job and writes the lockfile next to it (gemfiles/*.lock,
# gitignored, never committed). That resolved set is what the job actually
# installs, so it is what has to be audited against the Ruby advisory
# database, not only the committed root Gemfile.lock.
#
# The audit rides on the rake tasks every matrix entry already runs (rake
# compile, and the spec tasks when compile is skipped): the platform merge
# gate refuses new steps in a workflow, so the workflow file stays as it is
# and the audit runs from the Rakefile.
#
# The claim lives in the workflow file, the Rakefile and the script, so
# without this spec the audit could be dropped or neutered (a skipped
# prerequisite, a swallowed exit status) without anything going red. The
# wiring itself is pinned by RUNNING it (see the rake wiring group below):
# matching the Rakefile's source text passes on prose alone.
RSpec.describe 'CI dependency audits' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:workflow_file) { File.join(root, '.github/workflows/ci.yml') }
  let(:workflow) { YAML.safe_load_file(workflow_file, aliases: true) }
  let(:jobs) { workflow.fetch('jobs') }
  let(:script_path) { File.join(root, 'bin/audit-advisories') }
  let(:script) { File.read(script_path) }

  # Unlocked matrix gemfiles: resolved fresh on every CI run, never committed.
  let(:matrix_gemfiles) do
    Dir[File.join(root, 'gemfiles', '*.gemfile')].map { |path| File.basename(path) }.sort
  end

  # A stub bundle-audit: it records how it was called and exits with a given
  # status. The real one needs the advisory database and the network.
  def with_stub_audit(status:)
    Dir.mktmpdir('audit-advisories') do |dir|
      record = File.join(dir, 'record')
      stub = File.join(dir, 'bundle-audit')
      File.write(stub, <<~RUBY)
        #!#{RbConfig.ruby}
        call = [ARGV.join(' '), Dir.pwd, ENV['BUNDLE_GEMFILE'].to_s]
        File.write(#{record.dump}, call.join("\\n") + "\\n")
        exit #{status}
      RUBY
      File.chmod(0o755, stub)

      yield dir, record
    end
  end

  # What the stub recorded: the arguments it got, the working directory it
  # ran in and the BUNDLE_GEMFILE it saw.
  def recorded_call(record)
    argv, cwd, bundle_gemfile = File.read(record).lines.map(&:chomp)

    { argv: argv, cwd: cwd, bundle_gemfile: bundle_gemfile }
  end

  # The advisory ids the stub was told to ignore.
  def ignored_advisories(record)
    recorded_call(record)[:argv].split('--ignore').last.to_s.split
  end

  def run_audit(env, *args)
    # The script is standalone: it must not run inside the caller's bundle.
    standalone = { 'RUBYOPT' => nil, 'RUBYGEMS_GEMDEPS' => nil, 'BUNDLER_SETUP' => nil }
    Open3.capture3(standalone.merge(env), RbConfig.ruby, script_path, *args)
  end

  # bundle-audit resolves --gemfile-lock against its own working directory, so
  # the paths the script hands over are asserted relative to the repo root.
  def relative_to_root(path)
    Pathname.new(path).relative_path_from(Pathname.new(root)).to_s
  end

  # A lockfile that resolves the given gems to the given versions.
  def lockfile_with(dir, gems)
    specs = gems.map { |gem, version| "    #{gem} (#{version})" }.join("\n")

    File.join(dir, 'Gemfile.lock').tap do |lock|
      File.write(lock, "GEM\n  remote: https://rubygems.org/\n  specs:\n#{specs}\n")
    end
  end

  def steps_of(job)
    job['steps'].is_a?(Array) ? job['steps'] : []
  end

  # Steps that run bundle-audit (not the `gem install` of it).
  def audit_steps(job)
    steps_of(job).select { |step| step['run'].to_s.include?('bundle-audit check') }
  end

  def gemfile_of(job)
    job.dig('env', 'BUNDLE_GEMFILE').to_s
  end

  # Jobs that install an unlocked matrix gemfile.
  def matrix_jobs
    jobs.select { |_name, job| gemfile_of(job).end_with?('.gemfile') }
  end

  describe 'per-matrix audits' do
    it 'runs a rake task in every job that installs an unlocked gemfile' do
      expect(matrix_jobs).not_to be_empty, 'no CI job installs an unlocked gemfile'

      matrix_jobs.each do |name, job|
        rake_steps = steps_of(job).select { |step| step['run'].to_s.match?(/\brake\b/) }

        expect(rake_steps).not_to be_empty,
                                   "job #{name} installs #{gemfile_of(job)} but never runs a rake task"

        rake_steps.each do |step|
          expect(step['run'].to_s).to match(/\brake\b.*\b(compile|spec|audit)\b/),
                                     "job #{name} runs a rake task that does not reach the audit: #{step['run']}"
        end
      end
    end

    it 'never skips the compile step that carries the audit' do
      matrix_jobs.each do |name, job|
        expect(job.dig('env', 'SKIP_COMPILE')).to be_nil,
                                               "job #{name} sets SKIP_COMPILE: the audit never runs"

        steps_of(job).each do |step|
          expect(step.dig('env', 'SKIP_COMPILE')).to be_nil,
                                                 "job #{name} sets SKIP_COMPILE on a step: the audit never runs"
        end
      end
    end

    it 'keeps the audit out of the workflow steps' do
      matrix_jobs.each do |name, job|
        audit_steps(job).each do |step|
          expect(step['run'].to_s).not_to include('--gemfile-lock'),
                                      "job #{name} audits a lockfile in the workflow: the audit belongs in the Rakefile"
        end
      end
    end

    it 'covers every unlocked matrix gemfile in the repo' do
      covered = matrix_jobs.map { |_name, job| File.basename(gemfile_of(job)) }.uniq
      missing = matrix_gemfiles - covered

      expect(covered).to match_array(matrix_gemfiles),
                         "unlocked gemfiles with no CI job auditing the set it resolves: #{missing.join(', ')}"
    end
  end

  describe 'the rake wiring' do
    # Loading the Rakefile in a real rake run and invoking the tasks is the
    # only proof that survives a refactor: matching the Rakefile's source text
    # passes on prose alone — a dropped prerequisite, a body that never runs
    # the script. The driver (spec/ci/support/rake_wiring_driver.rb) runs
    # under `bundle exec` the way the CI jobs run rake, loads the Rakefile at
    # the top level the way rake does, and invokes audit:advisories against a
    # stub bundle-audit.
    let(:driver) { File.join(root, 'spec/ci/support/rake_wiring_driver.rb') }

    # Returns [report, fake_gemfile]: the driver's JSON report, and the
    # unlocked matrix gemfile (outside the repo) the Rakefile was loaded with.
    def run_rake_driver(extra = {})
      Dir.mktmpdir('rake-wiring') do |dir|
        gemfile = File.join(dir, 'standalone.gemfile')
        File.write(gemfile, "source 'https://rubygems.org'\n")
        File.write("#{gemfile}.lock", '')
        record = File.join(dir, 'record')
        report = File.join(dir, 'report.json')
        stub = File.join(dir, 'bundle-audit')

        File.write(stub, <<~RUBY)
          #!#{RbConfig.ruby}
          call = [ARGV.join(' '), Dir.pwd, ENV['BUNDLE_GEMFILE'].to_s]
          File.write(#{record.dump}, call.join("\\n") + "\\n")
          exit Integer(ENV.fetch('RUBY2HTML_STUB_STATUS', '0'))
        RUBY
        File.chmod(0o755, stub)

        env = {
          'RUBYOPT' => nil,
          'RUBYGEMS_GEMDEPS' => nil,
          'BUNDLER_SETUP' => nil,
          'PATH' => dir,
          'RUBY2HTML_SPEC_GEMFILE' => gemfile,
          'RUBY2HTML_SPEC_RECORD' => record,
          'RUBY2HTML_SPEC_REPORT' => report
        }.merge(extra)
        bundler = Gem.bin_path('bundler', 'bundle')

        out, err, status = Open3.capture3(env, RbConfig.ruby, bundler, 'exec', RbConfig.ruby, driver, chdir: root)
        raise "the rake wiring driver failed (#{status.exitstatus}): #{err}#{out}" unless status.success?

        [JSON.parse(File.read(report)), gemfile]
      end
    end

    it 'wires the audit into compile, ahead of the spec tasks' do
      report, = run_rake_driver

      expect(report.fetch('prerequisites').fetch('compile')).to include('audit:advisories')
      expect(report.fetch('prerequisites').fetch('spec')).to eq(%w[compile audit:advisories])
      expect(report.fetch('prerequisites').fetch('spec:gem')).to eq(%w[compile audit:advisories])
      expect(report.fetch('prerequisites').fetch('spec:standalone')).to eq(%w[compile audit:advisories])
    end

    it 'keeps the audit wired when compile is skipped (SKIP_COMPILE=1)' do
      report, = run_rake_driver('SKIP_COMPILE' => '1')

      expect(report.fetch('prerequisites').fetch('compile')).to include('audit:advisories')
      expect(report.fetch('prerequisites').fetch('spec:gem')).to eq(%w[audit:advisories]),
                                                                     'the audit must not depend on the compile step it does not need'
      expect(report.fetch('prerequisites').fetch('spec:standalone')).to eq(%w[audit:advisories])
    end

    it 'runs bin/audit-advisories when audit:advisories is invoked in CI for a matrix gemfile' do
      report, gemfile = run_rake_driver

      outcome = report.fetch('in_ci_with_matrix_gemfile')
      expect(outcome.fetch('ran')).to be(true), 'invoking audit:advisories in CI must run the audit'

      argv, cwd, bundle_gemfile = outcome.fetch('call')
      expect(argv).to eq("check --update --gemfile-lock #{relative_to_root("#{gemfile}.lock")}")
      expect(cwd).to eq(root), 'the audit runs in the project root, where the lockfile path it hands over resolves'
      expect(bundle_gemfile).to be_empty, 'the audit must run outside the caller Bundler environment'
    end

    it 'runs nothing outside CI' do
      report, = run_rake_driver

      expect(report.fetch('without_ci')).to include('ran' => false), 'the audit must not run outside CI'
    end

    it 'runs nothing for the committed root Gemfile' do
      report, = run_rake_driver

      expect(report.fetch('with_root_gemfile')).to include('ran' => false),
                                                    'the audit is for the unlocked matrix gemfiles; the root lockfile has its own job'
    end

    it 'fails the rake task when the audit finds an advisory' do
      report, = run_rake_driver

      outcome = report.fetch('failing_audit')
      expect(outcome.fetch('ran')).to be(true)
      expect(outcome.fetch('raised')).to eq('RuntimeError'), 'a failing audit must raise out of the rake task'
      expect(outcome.fetch('message')).to include('status (1)'), 'the audit exit status must surface'
    end
  end

  describe 'bin/audit-advisories' do
    it 'is an executable script' do
      expect(script).to start_with("#!/usr/bin/env ruby\n# frozen_string_literal: true\n")
      expect(File.executable?(script_path)).to be(true), 'bin/audit-advisories must be executable'
    end

    it 'runs without Bundler: the rake task shells out without bundle exec' do
      expect(script).not_to match(/require ['"]bundler|Bundler\./),
                           'bin/audit-advisories must not depend on Bundler being loadable'
    end

    it 'reports a signal-killed audit instead of passing it off as an advisory' do
      Dir.mktmpdir('audit-advisories') do |dir|
        stub = File.join(dir, 'bundle-audit')
        lock = File.join(dir, 'Gemfile.lock')
        File.write(lock, '')
        File.write(stub, <<~RUBY)
          #!#{RbConfig.ruby}
          Process.kill('TERM', Process.pid)
        RUBY
        File.chmod(0o755, stub)

        _out, err, status = run_audit({ 'PATH' => dir }, lock)

        expect(status.exitstatus).to eq(1), 'a killed audit must still fail the job'
        expect(err).to include('signal'), 'a killed audit must be reported as killed, not look like an advisory result'
      end
    end

    it 'audits the lockfile Bundler wrote next to BUNDLE_GEMFILE' do
      with_stub_audit(status: 0) do |dir, record|
        gemfile = File.join(dir, 'standalone.gemfile')
        lock = "#{gemfile}.lock"
        File.write(lock, '')

        _out, _err, status = run_audit({ 'PATH' => dir, 'BUNDLE_GEMFILE' => gemfile })

        expect(status.exitstatus).to eq(0)
        call = recorded_call(record)
        expect(call[:argv]).to eq("check --update --gemfile-lock #{relative_to_root(lock)}")
        expect(call[:bundle_gemfile]).to be_empty, 'the audit must run outside the caller Bundler environment'
      end
    end

    it 'audits the committed root Gemfile.lock without arguments' do
      with_stub_audit(status: 0) do |dir, record|
        _out, _err, status = run_audit({ 'PATH' => dir, 'BUNDLE_GEMFILE' => nil })

        expect(status.exitstatus).to eq(0)
        call = recorded_call(record)
        expect(call[:argv]).to eq('check --update --gemfile-lock Gemfile.lock')
      end
    end

    it 'hands bundle-audit a lockfile path it resolves from its working directory' do
      with_stub_audit(status: 0) do |dir, record|
        gemfile = File.join(dir, 'standalone.gemfile')
        lock = "#{gemfile}.lock"
        File.write(lock, '')

        _out, _err, status = run_audit({ 'PATH' => dir, 'BUNDLE_GEMFILE' => gemfile })

        expect(status.exitstatus).to eq(0)
        call = recorded_call(record)
        resolved = File.expand_path(File.join(call[:cwd], call[:argv].split.last))

        expect(resolved).to eq(lock), 'bundle-audit resolves --gemfile-lock against its working directory'
        expect(File.file?(resolved)).to be(true), 'the lockfile bundle-audit resolves must exist'
      end
    end

    it 'propagates a non-zero bundle-audit exit status' do
      with_stub_audit(status: 1) do |dir, _record|
        lock = File.join(dir, 'Gemfile.lock')
        File.write(lock, '')

        _out, _err, status = run_audit({ 'PATH' => dir }, lock)

        expect(status.exitstatus).to eq(1), 'an advisory must fail the script, and with it the CI job'
      end
    end

    it 'installs bundler-audit when the binary is missing' do
      Dir.mktmpdir('audit-advisories') do |dir|
        record = File.join(dir, 'record')
        install_log = File.join(dir, 'install')
        bin = File.join(dir, 'bundle-audit')
        installer = File.join(dir, 'gem')

        File.write(installer, <<~RUBY)
          #!#{RbConfig.ruby}
          File.write(#{install_log.dump}, ARGV.join(' '))
          File.write(#{bin.dump}, "#!#{RbConfig.ruby}\\nFile.write('#{record}', ARGV.join(' '))\\nexit 0\\n")
          File.chmod(0o755, #{bin.dump})
        RUBY
        File.chmod(0o755, installer)

        lock = File.join(dir, 'Gemfile.lock')
        File.write(lock, '')

        _out, _err, status = run_audit({ 'PATH' => dir }, lock)

        expect(status.exitstatus).to eq(0)
        expect(File.read(install_log)).to include('install', 'bundler-audit')
        expect(File.read(record)).to include("check --update --gemfile-lock #{relative_to_root(lock)}")
      end
    end

    it 'can find the gem executable beyond PATH when it installs bundler-audit' do
      expect(script).to include("gem_executable('gem')"),
                     'the gem executable may be missing from PATH too: the installer must look in the RubyGems bindir'
    end

    it 'refuses to continue when bundler-audit cannot be installed' do
      Dir.mktmpdir('audit-advisories') do |dir|
        installer = File.join(dir, 'gem')
        lock = File.join(dir, 'Gemfile.lock')
        File.write(lock, '')

        File.write(installer, <<~RUBY)
          #!#{RbConfig.ruby}
          exit 1
        RUBY
        File.chmod(0o755, installer)

        _out, err, status = run_audit({ 'PATH' => dir }, lock)

        expect(status.exitstatus).not_to eq(0)
        expect(err).to include('could not install bundler-audit')
      end
    end

    it 'refuses to audit a lockfile that does not exist' do
      with_stub_audit(status: 0) do |dir, _record|
        missing = File.join(dir, 'missing.lock')

        _out, err, status = run_audit({ 'PATH' => dir }, missing)

        expect(status.exitstatus).not_to eq(0)
        expect(err).to include('missing.lock')
      end
    end
  end

  describe 'the accepted advisories' do
    # The advisories the script accepts, read from the script itself.
    def script_accept_list
      block = script[/ACCEPTED_ADVISORIES = \{(.*?)\n\}\.freeze/m, 1]
      raise 'bin/audit-advisories declares no ACCEPTED_ADVISORIES' if block.nil?

      block.scan(/'([\w-]+)' => \{(.*?)\}/m).to_h do |gem, body|
        versions = {}
        body.scan(/'([^']+)' => %w\[(.*?)\]/m) do |version, ids|
          versions[version] = ids.split
        end
        [gem, versions]
      end
    end

    # The reviewed policy, pinned here INDEPENDENTLY of the script: an edit to
    # the script's table (an id typo'd, an entry added, dropped or moved to
    # another version) fails this spec and forces a conscious re-review. The
    # versions are what the matrix resolves on the floor lines today (see
    # bin/audit-advisories); once a resolution moves, the audit drops every
    # exception and fails the entry, so this snapshot can only change in step
    # with a real re-review. A gem can pin several versions when the matrix
    # resolves its line more than once: the rails gem pins Active Support
    # 7.2.3 for the Rails entries, while the standalone gemfile on Ruby 3.1
    # resolves the line unlocked and sits on the newest 7.2.x patch.
    let(:expected_accepted) do
      {
        'actionmailbox' => { '7.2.3' => %w[GHSA-5957-c7qm-m469] },
        'actionpack' => { '7.2.3' => %w[
          GHSA-2586-8ghr-69fj
          GHSA-gmj8-hvj3-49mw
          GHSA-r9jg-fmfx-2gv6
          GHSA-rwvh-fw6r-pwvp
          GHSA-wm3x-v3qw-4jh3
          GHSA-x6mj-8jx9-qhqv
        ] },
        'actionview' => { '7.2.3' => %w[
          GHSA-2p2f-4rq4-gjwc
          GHSA-68p9-83h6-5wpj
          GHSA-rq8q-p985-fjq7
          GHSA-v55j-83pf-r9cq
          GHSA-v6rj-xm57-3p59
        ] },
        'activestorage' => { '7.2.3' => %w[
          GHSA-3f4q-8x5m-76v8
          GHSA-3w93-6hmw-whh4
          GHSA-73f9-jhhh-hr5m
          GHSA-9xrj-h377-fr87
          GHSA-f3w6-w445-fwh9
          GHSA-hfr4-8rjc-97m2
          GHSA-p2pm-g2h6-7j5j
          GHSA-p9fm-f462-ggrg
          GHSA-qcfx-2mfw-w4cg
          GHSA-r46p-8f7g-vvvg
          GHSA-v924-7rp8-4mxh
          GHSA-xr9x-r78c-5hrm
        ] },
        'activesupport' => { '7.2.3' => %w[
          GHSA-2j26-frm8-cmj9
          GHSA-8474-xrp6-wh69
          GHSA-89vf-4333-qx8v
          GHSA-cg4j-q9v8-6v38
        ], '7.2.4' => %w[GHSA-8474-xrp6-wh69] }
      }
    end

    let(:pinned_activesupport) { expected_accepted.fetch('activesupport').keys.first }

    it 'accepts exactly the reviewed list, scoped to the exact reviewed version' do
      expect(script_accept_list).to eq(expected_accepted), 'the accept list changed: re-review it, then update this snapshot'
    end

    it 'declares every reviewed version on the documented 7.2 floor line' do
      script_accept_list.each do |gem, versions|
        expect(versions).not_to be_empty, "no reviewed version for #{gem}"

        versions.each_key do |version|
          expect(version).to match(/\A7\.2\.\d+(?:\.\d+)*\z/), "the reviewed version must sit on the Rails 7.2 floor line: #{gem} #{version}"
        end
      end
    end

    it 'lists well-formed advisory ids, never under two gems' do
      ids = script_accept_list.flat_map { |_gem, versions| versions.values.flatten }

      expect(ids).not_to be_empty, 'the script accepts no advisory at all'
      ids.each do |id|
        expect(id).to match(/\A(?:GHSA|CVE)-[A-Za-z0-9-]+\z/), "#{id} is not an advisory id"
      end

      # bundle-audit --ignore is global per run: an id parked under two gems
      # would be ignored while auditing either. The same id on two reviewed
      # versions of ONE gem is fine — only one of them resolves per run, and
      # the ids are scoped to the resolved version (proven below).
      gems_of = Hash.new { |hash, key| hash[key] = [] }
      script_accept_list.each do |gem, versions|
        versions.each_value { |gem_ids| gem_ids.each { |id| gems_of[id] |= [gem] } }
      end

      expect(gems_of.select { |_id, gems| gems.size > 1 }).to be_empty,
                                                             'an id listed under two gems would be ignored while auditing either — review the pair'
    end

    it 'accepts exactly the ids of the reviewed version the lockfile resolves' do
      expected_accepted.fetch('activesupport').each do |version, ids|
        with_stub_audit(status: 0) do |dir, record|
          lock = lockfile_with(dir, 'activesupport' => version)

          _out, _err, status = run_audit({ 'PATH' => dir }, lock)

          expect(status.exitstatus).to eq(0)
          expect(ignored_advisories(record)).to match_array(ids),
                                                 "a lockfile resolving #{version} must carry exactly its own exceptions"
        end
      end
    end

    it 'names the accepted advisories in the job log' do
      with_stub_audit(status: 0) do |dir, _record|
        lock = lockfile_with(dir, 'activesupport' => pinned_activesupport)

        out, _err, status = run_audit({ 'PATH' => dir }, lock)

        expect(status.exitstatus).to eq(0)
        expect(out).to include(expected_accepted.fetch('activesupport').fetch(pinned_activesupport).first),
                       'the job log must name the advisories the audit accepts'
      end
    end

    it 'drops every exception for an unreviewed patch of the same line' do
      with_stub_audit(status: 1) do |dir, record|
        unreviewed_patch = expected_accepted.fetch('activesupport').keys.max.succ # the next 7.2.x patch
        lock = lockfile_with(dir, 'activesupport' => unreviewed_patch)

        _out, _err, status = run_audit({ 'PATH' => dir }, lock)

        expect(recorded_call(record)[:argv]).not_to include('--ignore'),
                                                      'a version that was not reviewed must be audited without exceptions'
        expect(status.exitstatus).to eq(1), 'its advisories must fail the job until the new version is reviewed'
      end
    end

    it 'audits a newer line without any exception and fails the job on its advisories' do
      with_stub_audit(status: 1) do |dir, record|
        lock = lockfile_with(dir, 'activesupport' => '8.1.4.1')

        _out, _err, status = run_audit({ 'PATH' => dir }, lock)

        expect(recorded_call(record)[:argv]).not_to include('--ignore'),
                                                      'a line outside the accepted versions must be audited without exceptions'
        expect(status.exitstatus).to eq(1), 'the advisory bundle-audit reported must fail the script, and with it the CI job'
      end
    end

    it 'accepts advisories of the resolved gem only' do
      with_stub_audit(status: 0) do |dir, record|
        lock = lockfile_with(dir, 'activesupport' => pinned_activesupport)

        _out, _err, status = run_audit({ 'PATH' => dir }, lock)

        expect(status.exitstatus).to eq(0)
        ignored = ignored_advisories(record)

        script_accept_list.each do |gem, versions|
          next if gem == 'activesupport'

          versions.each_value do |ids|
            ids.each do |id|
              expect(ignored).not_to include(id),
                                     "the audit accepted #{id}, an advisory of #{gem}, which it does not resolve"
            end
          end
        end
      end
    end

    it 'keeps the root lockfile free of exceptions' do
      with_stub_audit(status: 0) do |dir, record|
        _out, _err, status = run_audit({ 'PATH' => dir })

        expect(status.exitstatus).to eq(0)
        expect(recorded_call(record)[:argv]).not_to include('--ignore'),
                                                      'the committed root Gemfile.lock must be audited without exceptions'
      end
    end
  end

  describe 'audit fatality' do
    it 'makes a failed audit reach the aggregate CI OK job' do
      aggregate = jobs.find { |id, job| id == 'ci-ok' || job['name'] == 'CI OK' }&.last

      expect(aggregate).not_to be_nil, 'the aggregate CI OK job is missing'
      needs = Array(aggregate['needs']).map(&:to_s)

      matrix_jobs.each_key do |name|
        expect(needs).to include(name), "job #{name} audits dependencies but is not required by the CI OK job"
      end
    end
  end

  describe 'root audit' do
    it 'still audits the committed root Gemfile.lock' do
      root_audits = jobs.reject { |_name, job| gemfile_of(job).end_with?('.gemfile') }
                        .flat_map { |name, job| audit_steps(job).map { |step| [name, step] } }
                        .reject { |_name, step| step['run'].to_s.include?('--gemfile-lock') }

      expect(root_audits).not_to be_empty,
                                 'no job runs bundle-audit check without --gemfile-lock (the default Gemfile.lock)'
    end

    it 'keeps the root audit job required by the CI OK job' do
      aggregate = jobs.find { |id, job| id == 'ci-ok' || job['name'] == 'CI OK' }&.last
      needs = Array(aggregate['needs']).map(&:to_s)

      expect(needs).to include('audit'), 'the root Gemfile.lock audit is not required by the CI OK job'
    end
  end

  it 'keeps the matrix lockfiles out of git' do
    ignored = File.readlines(File.join(root, '.gitignore'), chomp: true).map(&:strip)

    expect(ignored).to include('/gemfiles/*.lock')
  end

  it 'states which dependency sets are audited' do
    names = jobs.map { |_id, job| job['name'].to_s } +
            jobs.flat_map { |_id, job| steps_of(job).map { |step| step['name'].to_s } }
    comments = File.readlines(workflow_file).filter_map { |line| line[/^\s*#\s*(.*)$/, 1] }
    stated = (names + comments).join("\n")

    expect(stated).to include('Gemfile.lock'), 'the workflow does not name the audited root Gemfile.lock'
    matrix_gemfiles.each do |gemfile|
      expect(stated).to include("gemfiles/#{gemfile}"), "the workflow does not name the audited gemfiles/#{gemfile}"
    end
  end

  it 'documents the audited dependency sets in the repo guide' do
    row = File.readlines(File.join(root, 'AGENTS.md')).find { |line| line.start_with?('| CI |') }

    expect(row).not_to be_nil, 'the AGENTS.md CI row is missing'
    expect(row.to_s).to match(/bundle-audit|audit-advisories/)
    expect(row.to_s).to include('Gemfile.lock')
    expect(row.to_s).to include('gemfile')
  end
end
