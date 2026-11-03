# frozen_string_literal: true

h1 'RbFiles'
h1 'ok'
h1 'okddwadwa'

div @value

form_with url: '/test' do |f|
  f.text_field :name, placeholder: 'Name'
  f.submit 'Submit'
end

link_to 'Home', root_url
render partial: 'shared/navbar'
render partial: 'shared/footer'

div @value
