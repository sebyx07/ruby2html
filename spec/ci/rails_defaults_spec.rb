# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# Offline guard for the demo app's Rails floor: the app, the floor the gem
# advertises and the CI matrix must agree. No Rails, no network.
RSpec.describe 'bin/rails-defaults-check' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:app_config) { File.join(root, 'config', 'application.rb') }
  let(:app_floor) { File.read(app_config)[/config\.load_defaults\s+(\d+(?:\.\d+)*)/, 1] }
  # The files that advertise the floor the gem supports: the guard compares
  # each of them with the app's floor and names the ones that drift.
  let(:advertised_files) { %w[README.md llms.txt AGENTS.md] }
  # A Rails version the app does not use: the next major, derived so a
  # legitimate floor change needs no edit here.
  let(:divergent_floor) { "#{app_floor.to_i + 1}.0" }

  def run_script(*args)
    Open3.capture2e(RbConfig.ruby, *args, chdir: root)
  end

  # A copy of the files the guard reads, so a drifted copy can be checked
  # without touching the checkout.
  def copy_guard_tree(dir)
    FileUtils.mkdir_p(File.join(dir, 'bin'))
    FileUtils.mkdir_p(File.join(dir, 'config'))
    FileUtils.cp(app_config, File.join(dir, 'config', 'application.rb'))
    %w[rails-defaults-check rails-versions].each do |script|
      FileUtils.cp(File.join(root, 'bin', script), File.join(dir, 'bin', script))
    end
    advertised_files.each { |file| FileUtils.cp(File.join(root, file), File.join(dir, file)) }
  end

  it 'derives the Rails floor from the demo app' do
    stdout, status = run_script(File.join(root, 'bin', 'rails-versions'), '--floor')

    expect(status).to be_success
    expect(app_floor).to match(/\A\d+(\.\d+)*\z/)
    expect(stdout.strip).to eq(app_floor)
  end

  it 'passes when the app floor and the advertised floor agree' do
    stdout, status = run_script(File.join(root, 'bin', 'rails-defaults-check'))

    expect(status).to be_success
    expect(stdout).to include("app floor (config/application.rb): #{app_floor}")
    # Every advertised file is compared and reported with the floor found in
    # it: a guard that stopped comparing them would not name them at all.
    advertised_files.each { |file| expect(stdout).to include("#{file}: #{app_floor}") }
  end

  it 'fails when an advertised file drifts from the app floor' do
    Dir.mktmpdir do |dir|
      copy_guard_tree(dir)
      File.write(File.join(dir, 'AGENTS.md'), "Rails #{divergent_floor}+\n")

      stdout, status = run_script(File.join(dir, 'bin', 'rails-defaults-check'))

      expect(status).not_to be_success
      expect(stdout).to include("app floor (config/application.rb): #{app_floor}")
      expect(stdout).to include("AGENTS.md: #{divergent_floor}")
      expect(stdout).to include('Align AGENTS.md with config/application.rb')
    end
  end

  it 'fails when the CI matrix starts at another Rails than the app' do
    stdout, status = run_script(File.join(root, 'bin', 'rails-defaults-check'), JSON.generate([divergent_floor]))

    expect(status).not_to be_success
    expect(stdout).to include("app floor (config/application.rb): #{app_floor}")
    expect(stdout).to include("CI matrix (oldest entry): #{divergent_floor}")
    expect(stdout).to include('Align CI matrix with config/application.rb')
  end
end
