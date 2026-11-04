# frozen_string_literal: true

class SecondComponent < ApplicationComponent
  def call
    html do
      h1 class: 'my-class' do
        plain 'Second Component'
      end
      link_to 'Home', root_path
    end
  end
end
