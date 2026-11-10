# frozen_string_literal: true

# Guards the single-source Ruby pin: .ruby-version is the only file holding
# the literal version, mise.toml derives its [tools] entry from it through the
# read_file template, and bin/setup installs the toolchain with a bare
# `mise install`. A version literal sneaking back into mise.toml, the template
# referencing another file, a non-X.Y.Z pin or an explicit `ruby@` argument in
# bin/setup all fail this spec.
RSpec.describe '.ruby-version as the single Ruby version source' do
  let(:ruby_version) { File.read(File.expand_path('../../.ruby-version', __dir__)).strip }
  let(:mise_toml) { File.read(File.expand_path('../../mise.toml', __dir__)) }
  let(:setup_script) { File.read(File.expand_path('../../bin/setup', __dir__)) }
  let(:ruby_request) do
    mise_toml[/^\s*ruby\s*=\s*"([^"]*)"/, 1] || raise('mise.toml has no ruby = "..." entry')
  end

  it 'keeps an exact X.Y.Z version literal in .ruby-version' do
    expect(ruby_version).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it 'derives the mise ruby request from .ruby-version, never from a version literal' do
    expect(ruby_request).to include("read_file(path='.ruby-version')")
  end

  it 'resolves the referenced file to the .ruby-version content' do
    referenced_path = ruby_request[/read_file\(\s*path\s*=\s*'([^']*)'\s*\)/, 1]

    expect(referenced_path).to eq('.ruby-version')
    referenced = File.read(File.expand_path("../../#{referenced_path}", __dir__)).strip
    expect(referenced).to eq(ruby_version)
  end

  it 'installs the toolchain with a bare `mise install` and no ruby@ version argument' do
    mise_calls = setup_script.scan(/system!\('(mise [^']*)'\)/).flatten

    expect(mise_calls).to eq(['mise install'])
  end
end
