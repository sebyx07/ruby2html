# frozen_string_literal: true

require 'json'
require 'open3'
require 'rbconfig'

# Offline guard for the demo app's Rails floor: the app, the floor the gem
# advertises and the CI matrix must agree. No Rails, no network.
RSpec.describe 'bin/rails-defaults-check' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:app_config) { File.join(root, 'config', 'application.rb') }
  let(:app_floor) { File.read(app_config)[/config\.load_defaults\s+(\d+(?:\.\d+)*)/, 1] }
  # A Rails version the app does not use: the next major, derived so a
  # legitimate floor change needs no edit here.
  let(:divergent_floor) { "#{app_floor.to_i + 1}.0" }

  def run_script(*args)
    Open3.capture2e(RbConfig.ruby, *args, chdir: root)
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
    expect(stdout).to include(app_floor)
  end

  it 'fails when the CI matrix starts at another Rails than the app' do
    stdout, status = run_script(File.join(root, 'bin', 'rails-defaults-check'), JSON.generate([divergent_floor]))

    expect(status).not_to be_success
    expect(stdout).to include(app_floor).and include(divergent_floor)
    expect(stdout).to include('CI matrix')
  end
end
