# frozen_string_literal: true

class FirstComponent < ApplicationComponent
  def initialize
    @item = 'Hello, World!'
  end

  def another_div
    div do
      "Item value: #{@item}"
    end

    div class: 'another' do
      h2 'Another subheading from component'
    end

    h1 'Yet Another heading from component'
  end
end
