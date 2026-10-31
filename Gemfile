# frozen_string_literal: true

source 'https://rubygems.org'

gem 'rails', '~> 8.1'
gem 'sprockets-rails'
gem 'sqlite3', '>= 1.4'
gem 'puma', '>= 5.0'
gem 'tzinfo-data', platforms: %i[ windows jruby ]
gem 'htmlbeautifier'
gem 'bootsnap', require: false

group :development, :test do
  gem 'brakeman', require: false
end

group :development do
  gem 'web-console'
end

gem 'rubocop-rails_config', '~> 1.17', require: false

gem 'pry-rails', '~> 0.3.11'

gem 'view_component', '~> 4.0'

gem 'rspec-rails', '~> 8.0'

gem 'capybara', '~> 3.40'

gem 'lefthook', '~> 2.0'

gem 'faker', '~> 3.8'

gem 'slim-rails', '~> 4.0'

gem 'phlex-rails', '~> 2.4'

gem 'rake-compiler', '~> 1.3', require: false

group :test do
  gem 'benchmark-ips'
end

# phlex 2.x -> refract uses Prism::MissingNode, which prism 2.x removed. Drop
# once refract supports prism 2 (also pinned in gemfiles/rails_common.rb).
gem 'prism', '~> 1.6'
