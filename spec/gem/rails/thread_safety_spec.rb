# frozen_string_literal: true

require 'rails_helper'
require_relative 'support/template_rendering'

# Puma renders requests on several threads at once: templates, partials,
# components and helper captures must not share mutable render state.
RSpec.describe 'Concurrent rendering' do
  include TemplateRendering

  let(:templates) do
    {
      'spec/show.html.rb' => "div(id: @id) do\n  render partial: 'spec/item', locals: { n: @id }\n  " \
                             "render(BadgeComponent.new(@id)) { em @id }\n  link_to('/') { b @id }\n  " \
                             "content_for(:x) { i @id }\nend\nplain content_for(:x)",
      'spec/_item.html.rb' => 'span n'
    }
  end

  before do
    stub_const('BadgeComponent', Class.new(Ruby2html::Component) do
      def initialize(id) = @id = id
      def view_template = strong(@id) { content }
    end)
  end

  def expected(id)
    %(<div id="#{id}"><span>#{id}</span><strong><em>#{id}</em></strong><a href="/"><b>#{id}</b></a></div><i>#{id}</i>)
  end

  # One controller class for every thread, as in a booted app: a new class (and resolver) per
  # render races ActionView's view-path setup on JRuby's parallel threads (MissingTemplate).
  it 'renders the same output on many threads as on one' do
    controller = template_controller(templates)
    controller.render(template: 'spec/show', assigns: { id: 'warm' }) # compile once up front
    results = Array.new(8) do |t|
      Thread.new { Array.new(25) { |i| id = "t#{t}-#{i}"; [id, controller.render(template: 'spec/show', assigns: { id: })] } }
    end.flat_map(&:value)
    expect(results).to all(satisfy { |id, html| html == expected(id) })
  end
end
