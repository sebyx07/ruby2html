# frozen_string_literal: true

div do
  h1 'form'

  form_with url: '/form', method: 'post' do |f|
    f.label :name
    f.text_field :name
    f.submit 'submit'
  end

  link_to 'Home', root_path
  # button_to 'home', '/'
end
