# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Homes', type: :feature do
  it 'can visit root' do
    visit root_path
    expect(page).to have_content('Hello')
  end

  it 'can visit rb_files' do
    visit rb_files_path
    expect(page).to have_content('RbFiles')
  end
end
