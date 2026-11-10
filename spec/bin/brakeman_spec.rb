# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'

RSpec.describe 'bin/brakeman' do
  let(:script_path) { File.expand_path('../../bin/brakeman', __dir__) }
  # The version the bundle actually locks (Gemfile.lock), not a literal: this
  # spec cannot silently drift from the brakeman CI scans with.
  let(:locked_version) { Gem.loaded_specs['brakeman'].version.to_s }
  let(:upstream_version) { '99.0.0' }

  # bin/brakeman runs as a subprocess in a hermetic gem environment:
  # bundler/setup is stubbed out, the locked brakeman spec points at a fake
  # executable and Gem.latest_spec_for is stubbed, so nothing hits the network
  # (an unstubbed lookup raises the way rubygems.org-unreachable does, and is
  # logged so the specs can tell whether the script consulted it at all).
  # The fake executable records the arguments it was called with and exits
  # with the requested status, which keeps the script's own decisions
  # observable: which executable ran, what it was told and how the script
  # exited.
  def run_brakeman(args: [], latest: 'same', mode: 'normal', exit_code: 0, check_latest: false)
    Dir.mktmpdir do |dir|
      bin_dir = File.join(dir, 'locked', 'bin')
      empty_bin_dir = File.join(dir, 'locked', 'empty-bin')
      stub_dir = File.join(dir, 'stub')
      log = File.join(dir, 'brakeman.log')
      lookup_log = File.join(dir, 'lookup.log')
      decoy_log = File.join(dir, 'decoy.log')
      decoy = File.join(dir, 'decoy', 'brakeman')
      prelude = File.join(dir, 'prelude.rb')

      FileUtils.mkdir_p([bin_dir, empty_bin_dir, File.join(stub_dir, 'bundler'), File.dirname(decoy)])
      File.write(File.join(bin_dir, 'brakeman'), fake_brakeman_source)
      File.write(decoy, decoy_source)
      File.write(File.join(stub_dir, 'bundler', 'setup.rb'), stub_bundler_setup)
      File.write(prelude, prelude_source)

      env = {
        'RUBYOPT' => nil,
        'RUBYLIB' => stub_dir,
        'R2H_BIN_DIR' => bin_dir,
        'R2H_DECOY' => decoy,
        'R2H_DECOY_LOG' => decoy_log,
        'R2H_EMPTY_BIN_DIR' => empty_bin_dir,
        'R2H_EXIT' => exit_code.to_s,
        'R2H_LATEST' => latest,
        'R2H_LOG' => log,
        'R2H_LOOKUP_LOG' => lookup_log,
        'R2H_MODE' => mode,
        'R2H_UPSTREAM' => upstream_version,
        'R2H_VERSION' => locked_version,
        'RUBY2HTML_CHECK_LATEST' => check_latest ? '1' : nil
      }

      stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, '-r', prelude, script_path, *args)

      [
        stdout,
        stderr,
        status,
        File.exist?(log) ? File.read(log) : nil,
        File.exist?(decoy_log) ? File.read(decoy_log) : nil,
        File.exist?(lookup_log) ? File.read(lookup_log) : nil
      ]
    end
  end

  def stub_bundler_setup
    <<~'RUBY'
      # frozen_string_literal: true
      # bundler/setup is stubbed: the fake gem environment is enough here.
    RUBY
  end

  # The fake gem environment: the locked brakeman spec, a stubbed
  # Gem.latest_spec_for (newer, same or unreachable; unstubbed calls raise
  # instead of reaching rubygems.org) and a stubbed
  # Gem.bin_path that points at a decoy executable, so the script cannot
  # silently fall back to whatever brakeman happens to be installed.
  def prelude_source
    <<~'RUBY'
      # frozen_string_literal: true

      require 'rubygems'
      require 'rubygems/remote_fetcher'

      # Stands in for the locked Gem::Specification of brakeman.
      class FakeBrakemanSpec
        attr_reader :version, :bin_dir, :executables, :name

        def initialize(version, bin_dir)
          @version = Gem::Version.new(version)
          @bin_dir = bin_dir
          @executables = ['brakeman']
          @name = 'brakeman'
        end
      end

      # Replaces the two RubyGems lookups the script relies on. Every
      # latest_spec_for call is logged, so a spec can tell whether the script
      # consulted rubygems.org at all; an unstubbed call raises, keeping the
      # subprocess off the network.
      module FakeGemEnvironment
        def latest_spec_for(name, *args, **kwargs, &block)
          File.open(ENV.fetch('R2H_LOOKUP_LOG'), 'a') { |file| file.puts(name.to_s) }
          mode = ENV.fetch('R2H_LATEST', '')
          if mode.empty? || mode == 'offline'
            raise Gem::RemoteFetcher::FetchError.new('rubygems.org is unreachable', 'https://rubygems.org')
          end

          version = mode == 'same' ? ENV.fetch('R2H_VERSION') : ENV.fetch('R2H_UPSTREAM')
          Struct.new(:version).new(Gem::Version.new(version))
        end

        def bin_path(name, *args, **kwargs)
          decoy = ENV['R2H_DECOY']
          return super if decoy.nil? || decoy.empty?

          decoy
        end
      end

      Gem.singleton_class.prepend(FakeGemEnvironment)

      if ENV['R2H_MODE'] == 'missing_gem'
        Gem.loaded_specs.delete('brakeman')
      else
        bin_dir = ENV.fetch('R2H_BIN_DIR')
        bin_dir = ENV.fetch('R2H_EMPTY_BIN_DIR') if ENV['R2H_MODE'] == 'missing_executable'
        Gem.loaded_specs['brakeman'] = FakeBrakemanSpec.new(ENV.fetch('R2H_VERSION'), bin_dir)
      end
    RUBY
  end

  # Stands in for the brakeman executable of the locked gem spec: it records
  # its arguments, refuses the outdated-version option the way brakeman does
  # (exit code 5) and exits with the requested status otherwise.
  def fake_brakeman_source
    <<~'RUBY'
      #!/usr/bin/env ruby
      # frozen_string_literal: true

      File.open(ENV.fetch('R2H_LOG'), 'a') { |file| file.puts(ARGV.join(' ')) }

      if ARGV.any? { |arg| arg.include?('ensure-latest') }
        warn 'You are not running the latest version of Brakeman'
        exit 5
      end

      puts 'fake brakeman: scan complete'
      exit Integer(ENV.fetch('R2H_EXIT', '0'))
    RUBY
  end

  # The executable a Gem.bin_path lookup would return: it must never run.
  def decoy_source
    <<~'RUBY'
      #!/usr/bin/env ruby
      # frozen_string_literal: true

      File.open(ENV.fetch('R2H_DECOY_LOG'), 'a') { |file| file.puts('decoy') }
      exit 99
    RUBY
  end

  it 'runs the executable of the locked brakeman gem spec' do
    stdout, _stderr, status, log, decoy_log, lookup_log = run_brakeman(args: ['--no-pager'])

    expect(status).to be_success
    expect(stdout).to include('fake brakeman: scan complete')
    expect(log).to include('--no-pager')
    expect(decoy_log).to be_nil
    # Opt-in upstream check: the scan starts without a rubygems.org round trip.
    expect(lookup_log).to be_nil
  end

  it 'consults rubygems.org only when RUBY2HTML_CHECK_LATEST is set' do
    stdout, stderr, status, log, _decoy_log, lookup_log = run_brakeman(args: ['--no-pager'], check_latest: true)

    expect(status).to be_success
    expect(lookup_log).to include('brakeman')
    # Same version upstream: nothing to warn about, exit status untouched.
    expect(stderr).to be_empty
    expect(stdout).to include('fake brakeman: scan complete')
    expect(log).to include('--no-pager')
  end

  it 'reports a newer upstream brakeman on stderr without changing the exit status' do
    stdout, stderr, status, log = run_brakeman(args: ['--no-pager'], latest: 'newer', check_latest: true)

    expect(status).to be_success
    expect(status.exitstatus).not_to eq(5)
    expect(stderr).to include(locked_version)
    expect(stderr).to include(upstream_version)
    expect(stderr).not_to include('not running the latest version')
    expect(stdout).to include('fake brakeman: scan complete')
    expect(log).to include('--no-pager')
  end

  it 'never passes brakeman the ensure-latest option' do
    _stdout, stderr, status, log = run_brakeman(args: ['--no-pager'], latest: 'newer', check_latest: true)

    expect(status).to be_success
    expect(log).not_to include('ensure-latest')
    expect(stderr).not_to include('not running the latest version')
    expect(File.read(script_path)).not_to include('ensure-latest')
  end

  it 'keeps brakeman warnings fatal' do
    _stdout, _stderr, status, log = run_brakeman(args: ['--no-pager'], exit_code: 3)

    expect(status.exitstatus).to eq(3)
    expect(log).to include('--no-pager')
    expect(log).not_to include('exit-on-warn')
  end

  it 'runs the scan when rubygems.org cannot be reached' do
    stdout, stderr, status, log = run_brakeman(args: ['--no-pager'], latest: 'offline', check_latest: true)

    expect(status).to be_success
    expect(stdout).to include('fake brakeman: scan complete')
    expect(log).to include('--no-pager')
    expect(stderr).not_to include(upstream_version)
  end

  it 'aborts when brakeman is missing from the bundle' do
    stdout, stderr, status, log = run_brakeman(mode: 'missing_gem')

    expect(status.exitstatus).to eq(1)
    expect(stderr).to match(/brakeman.*not in the bundle/)
    expect(stdout).to be_empty
    expect(log).to be_nil
  end

  it 'aborts when the locked brakeman executable is missing' do
    stdout, stderr, status, log = run_brakeman(mode: 'missing_executable')

    expect(status.exitstatus).to eq(1)
    expect(stderr).to match(/brakeman executable missing/)
    expect(stdout).to be_empty
    expect(log).to be_nil
  end
end
