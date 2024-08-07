# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext/string/output_safety'

RSpec.describe Ruby2html::Render do
  let(:context) { double('context') }
  let(:render) { described_class.new(context) { div { p 'Hello, World!' } } }

  describe '#render' do
    it 'renders basic HTML' do
      expect(render.render).to eq('<div><p>Hello, World!</p></div>')
    end

    it 'renders nested elements' do
      render = described_class.new(context) do
        div do
          h1 'Title'
          p 'Paragraph'
        end
      end
      expect(render.render).to eq('<div><h1>Title</h1><p>Paragraph</p></div>')
    end

    it 'handles attributes' do
      render = described_class.new(context) do
        div class: 'container', id: 'main' do
          p 'Content'
        end
      end
      expect(render.render).to eq('<div class="container" id="main"><p>Content</p></div>')
    end

    it 'escapes HTML in content' do
      render = described_class.new(context) { p '<script>alert("XSS")</script>' }
      expect(render.render).to eq('<p>&lt;script&gt;alert(&quot;XSS&quot;)&lt;/script&gt;</p>')
    end

    it 'handles void elements' do
      render = described_class.new(context) { img src: 'image.jpg', alt: 'An image' }
      expect(render.render).to eq('<img src="image.jpg" alt="An image" />')
    end
  end

  describe '#plain' do
    it 'renders unescaped content for ActiveSupport::SafeBuffer' do
      safe_buffer = '<strong>Safe HTML</strong>'.html_safe
      render = described_class.new(context) { plain safe_buffer }
      expect(render.render).to eq('<strong>Safe HTML</strong>')
    end

    it 'escapes regular strings' do
      render = described_class.new(context) { plain '<em>Unsafe HTML</em>' }
      expect(render.render).to eq('&lt;em&gt;Unsafe HTML&lt;/em&gt;')
    end
  end

  describe '#component' do
    it 'renders component output' do
      component_output = '<custom-component>Content</custom-component>'
      render = described_class.new(context) { component component_output }
      expect(render.render).to eq(component_output)
    end
  end

  describe 'Rails helpers' do
    Ruby2html::Render::COMMON_RAILS_METHOD_HELPERS.each do |helper|
      it "delegates #{helper} to context" do
        helper_output = '<helper-output />'.html_safe
        expect(context).to receive(helper).and_return(helper_output)
        render = described_class.new(context) { send(helper) }
        expect(render.render).to eq(helper_output)
      end
    end
  end

  describe 'method_missing' do
    it 'delegates unknown methods to context' do
      expect(context).to receive(:custom_helper).and_return('Custom Helper Output')
      render = described_class.new(context) { plain(custom_helper) }
      expect(render.render).to eq('Custom Helper Output')
    end

    it 'raises NoMethodError or NameError for undefined methods' do
      render = described_class.new(context) { undefined_method }
      expect { render.render }.to raise_error(StandardError) # This will catch both NoMethodError and NameError
    end
  end

  describe 'instance variables' do
    it 'sets instance variables from context' do
      allow(context).to receive(:instance_variables).and_return([:@test_var])
      allow(context).to receive(:instance_variable_get).with(:@test_var).and_return('Test Value')

      render = described_class.new(context) { plain @test_var }
      expect(render.render).to eq('Test Value')
    end
  end
end
