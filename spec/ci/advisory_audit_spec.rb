# frozen_string_literal: true

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
# The audit rides on the rake task every matrix entry already runs (rake
# compile -> audit:advisories -> bin/audit-advisories): the platform merge
# gate refuses new steps in a workflow, so the workflow file stays as it is
# and the audit runs from the Rakefile.
#
# The claim lives in the workflow file, the Rakefile and the script, so
# without this spec the audit could be dropped or neutered (a skipped
# prerequisite, a swallowed exit status) without anything going red.
RSpec.describe 'CI dependency audits' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:workflow_file) { File.join(root, '.github/workflows/ci.yml') }
  let(:workflow) { YAML.safe_load_file(workflow_file, aliases: true) }
  let(:jobs) { workflow.fetch('jobs') }
  let(:rakefile) { File.read(File.join(root, 'Rakefile')) }
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
    it 'defines the audit:advisories task' do
      expect(rakefile).to match(/task\s+['"]audit:advisories['"]/)
    end

    it 'makes compile depend on audit:advisories' do
      expect(rakefile).to match(/Rake::Task\[:compile\].*enhance.*audit:advisories/m)
    end

    it 'runs the audit only in CI and only for the unlocked matrix gemfiles' do
      body = rakefile[/task\s+['"]audit:advisories['"]\s+do\n(.*?)\nend/m, 1]

      expect(body).not_to be_nil, 'the audit:advisories task has no body'
      expect(body).to include("ENV['CI']"), 'the audit must not run outside CI'
      expect(body).to include('BUNDLE_GEMFILE'), 'the audit must only run for the unlocked matrix gemfiles'
      expect(body).to include('.gemfile'), 'the audit must only run for the unlocked matrix gemfiles'
      expect(body).to include('bin/audit-advisories'), 'the task must run bin/audit-advisories'
    end
  end

  describe 'bin/audit-advisories' do
    # bundle-audit resolves --gemfile-lock against its own working directory,
    # so the script hands it a path relative to the project root.
    def relative_to_root(path)
      Pathname.new(path).relative_path_from(Pathname.new(root)).to_s
    end

    it 'is an executable script' do
      expect(script).to start_with("#!/usr/bin/env ruby\n# frozen_string_literal: true\n")
      expect(File.executable?(script_path)).to be(true), 'bin/audit-advisories must be executable'
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
          File.write(#{bin.dump}, "#!#{RbConfig.ruby}\nFile.write('#{record}', ARGV.join(' '))\nexit 0\n")
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
    # The advisories the script accepts, read from the script itself: the list
    # is the policy, the spec pins how the script applies it.
    def accepted_advisories
      block = script[/ACCEPTED_ADVISORIES = \{(.*?)\n\}\.freeze/m, 1]
      raise 'bin/audit-advisories declares no ACCEPTED_ADVISORIES' if block.nil?

      block.scan(/'([\w-]+)' => \{ '([^']+)' => %w\[(.*?)\] \}/m).to_h do |gem, requirement, ids|
        [gem, { requirement => ids.split }]
      end
    end

    it 'declares every accepted advisory by its id, scoped to one release line' do
      accepted = accepted_advisories

      expect(accepted).not_to be_empty, 'the script accepts no advisory at all'

      accepted.each_value do |ranges|
        ranges.each do |requirement, ids|
          expect(requirement).to start_with('~> '),
                                     "an accepted advisory must be scoped to one release line: #{requirement}"
          expect(ids).not_to be_empty, "no advisory id listed for #{requirement}"

          ids.each do |id|
            expect(id).to match(/\A(?:GHSA|CVE)-[A-Za-z0-9-]+\z/), "#{id} is not an advisory id"
          end
        end
      end
    end

    it 'accepts the advisories of the floor line the lockfile resolves' do
      with_stub_audit(status: 0) do |dir, record|
        lock = lockfile_with(dir, 'activesupport' => '7.2.4')

        _out, _err, status = run_audit({ 'PATH' => dir }, lock)

        expect(status.exitstatus).to eq(0)
        expect(ignored_advisories(record)).to match_array(accepted_advisories.fetch('activesupport')
                                                            .fetch('~> 7.2.0'))
      end
    end

    it 'names the accepted advisories in the job log' do
      with_stub_audit(status: 0) do |dir, _record|
        lock = lockfile_with(dir, 'activesupport' => '7.2.4')

        out, _err, status = run_audit({ 'PATH' => dir }, lock)

        expect(status.exitstatus).to eq(0)
        expect(out).to include('GHSA-8474-xrp6-wh69'),
                       'the job log must name the advisories the audit accepts'
      end
    end

    it 'audits a newer line without any exception' do
      with_stub_audit(status: 0) do |dir, record|
        lock = lockfile_with(dir, 'activesupport' => '8.1.4.1')

        _out, _err, status = run_audit({ 'PATH' => dir }, lock)

        expect(status.exitstatus).to eq(0)
        expect(recorded_call(record)[:argv]).not_to include('--ignore'),
                                                      'a line outside the accepted ranges must be audited without exceptions'
      end
    end

    it 'accepts advisories of the resolved gem only' do
      with_stub_audit(status: 0) do |dir, record|
        lock = lockfile_with(dir, 'activesupport' => '7.2.4')

        _out, _err, status = run_audit({ 'PATH' => dir }, lock)

        expect(status.exitstatus).to eq(0)
        accepted = accepted_advisories
        ignored = ignored_advisories(record)

        accepted.each do |gem, ranges|
          next if gem == 'activesupport'

          ranges.each_value do |ids|
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

    it 'still fails the job on an advisory it does not accept' do
      with_stub_audit(status: 1) do |dir, _record|
        lock = lockfile_with(dir, 'activesupport' => '7.2.4')

        _out, _err, status = run_audit({ 'PATH' => dir }, lock)

        expect(status.exitstatus).to eq(1), 'an advisory the audit does not accept must fail the CI job'
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
