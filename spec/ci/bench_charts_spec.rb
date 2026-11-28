# frozen_string_literal: true

require 'open3'
require 'rbconfig'

# The README's Performance charts and tables are generated from one committed
# benchmark run (docs/benchmarks/*.json) by bin/bench-charts. This keeps them
# from drifting: a hand-edited number, or a new run committed without
# regenerating, fails here.
RSpec.describe 'README benchmark charts' do
  let(:root) { File.expand_path('../..', __dir__) }

  it 'match the committed benchmark run (bin/bench-charts --check)' do
    out, status = Open3.capture2e(RbConfig.ruby, File.join(root, 'bin/bench-charts'), '--check')

    expect(status).to be_success, out
  end
end
