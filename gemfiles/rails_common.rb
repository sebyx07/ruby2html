# frozen_string_literal: true

# Shared by gemfiles/rails.gemfile: everything the demo app and its specs need
# besides Rails itself (and sqlite3, whose allowed range depends on Rails).
gem 'sprockets-rails'
gem 'bootsnap', require: false
gem 'tzinfo-data', platforms: %i[windows jruby]
gem 'htmlbeautifier'
gem 'view_component', '>= 3.13'
gem 'phlex-rails', '>= 1.2'
gem 'slim-rails', '>= 3.6'
gem 'rake-compiler', '~> 1.2', require: false

group :test do
  gem 'rspec-rails', '>= 6.1'
  gem 'capybara', '~> 3.40'
  gem 'faker', '>= 3.4'
  gem 'benchmark-ips'
end

# phlex 2.x -> refract uses Prism::MissingNode, which prism 2.x removed; Bundler
# would otherwise pick prism 2 under Rails 8.1. Drop once refract supports it.
gem 'prism', '~> 1.6'
