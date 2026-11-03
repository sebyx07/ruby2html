# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'

RSpec.describe 'bin/setup' do
  # The script runs as a subprocess with a PATH that contains only stub
  # executables. Each stub appends its command line to a shared log and exits
  # 0, so no real mise, bundler, rake or lefthook work happens and .git is
  # never touched; --skip-db keeps the Rails database step out of the picture.
  def run_setup(*stub_names)
    Dir.mktmpdir do |dir|
      stub_names.each { |name| write_stub(dir, name) }
      log = File.join(dir, 'calls.log')
      env = { 'PATH' => dir, 'R2H_STUB_LOG' => log, 'RUBYOPT' => nil }
      stdout, status = Open3.capture2(env, RbConfig.ruby, script_path, '--skip-db')
      [stdout, status, File.readlines(log, chomp: true)]
    end
  end

  def write_stub(dir, name)
    path = File.join(dir, name)
    File.write(path, <<~'SH')
      #!/bin/sh
      printf '%s\n' "${0##*/} $*" >> "${R2H_STUB_LOG:-/dev/null}"
      exit 0
    SH
    FileUtils.chmod(0o755, path)
  end

  let(:script_path) { File.expand_path('../../bin/setup', __dir__) }

  it 'runs mise install when the version check succeeds, before the first bundle call' do
    _stdout, status, calls = run_setup('bundle', 'mise')

    expect(status).to be_success
    expect(calls.take(2)).to eq(['mise --version', 'mise install'])
    first_bundle_call = calls.find_index { |call| call.start_with?('bundle ') }
    expect(first_bundle_call).to be > 1
  end

  it 'prints a skip note and continues when mise is absent' do
    stdout, status, calls = run_setup('bundle')

    expect(status).to be_success
    expect(stdout).to include('mise not found: skipped (using the active Ruby)')
    expect(calls.first).to eq('bundle check')
  end
end
