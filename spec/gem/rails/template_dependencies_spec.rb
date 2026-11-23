# frozen_string_literal: true

require 'open3'
require 'rails_helper'

# Fragment caching (`cache(...) { }`) digests a template together with the
# partials it renders; without a tracker for .html.rb templates, editing a
# partial would leave stale cached fragments behind.
RSpec.describe 'Template dependency tracking' do
  let(:source) do
    <<~RUBY
      div do
        render partial: 'posts/item', locals: { a: 1 }
        render 'posts/footer'
        render @posts
        link_to('/') { render 'shared/icon' }
      end
    RUBY
  end

  let(:template) do
    ActionView::Template.new(source, 'posts/show.html.rb', Ruby2html::TemplateHandler, locals: [], format: :html, virtual_path: 'posts/show')
  end

  # Rendering loads ActionView::Base, which runs the :action_view hooks that register the
  # handler and its tracker. Load it here too: the example must not depend on spec order.
  before { ActionView::Base }

  it 'finds the partials an .html.rb template renders' do
    expect(ActionView::DependencyTracker.find_dependencies('posts/show', template))
      .to contain_exactly('posts/item', 'posts/footer', 'posts/post', 'shared/icon')
  end

  # A fresh process: ActionView::Base loads before the Digestor (Rails 7.2 without an app).
  it 'loads with ActionView alone, before the Digestor' do
    script = "require 'uri'; require 'action_view'; require 'ruby2html'; ActionView::Base; print :ok"
    out, err, status = Open3.capture3(RbConfig.ruby, '-I', File.expand_path('../../../lib/gem', __dir__), '-e', script)

    expect([status.success?, out]).to eq([true, 'ok']), err
  end
end
