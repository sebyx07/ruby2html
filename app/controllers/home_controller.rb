# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @items = [
      {
        title: 'Item 1',
        description: 'Description 1'
      }
    ]
  end
end
