# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.4.5'

gem 'aasm'
gem 'bcrypt', '~> 3.1.7'
gem 'bootsnap', require: false
gem 'gl_command', git: 'https://github.com/givelively/gl_command.git'
gem 'haml-rails'
gem 'importmap-rails'
gem 'oj'
gem 'pg', '~> 1.1'
gem 'puma'
gem 'rails'
gem 'sassc-rails'
gem 'sentry-rails'
gem 'sentry-ruby'
gem 'sprockets-rails'
gem 'stimulus-rails'
gem 'tailwindcss-rails'
gem 'turbo-rails'
gem 'view_component'

group :development, :test do
  gem 'brakeman'
  gem 'bundler-audit'
  gem 'cucumber', require: false
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'dotenv-rails'
  gem 'erb_lint', require: false
  gem 'factory_bot_rails'
  gem 'gherkin_lint', require: false
  gem 'packwerk'
  gem 'reek'
  gem 'timecop'

  gem 'rswag-api'
  gem 'rswag-specs'
  gem 'rswag-ui'
end

group :development do
  gem 'gl_lint', require: false
  gem 'listen'
  gem 'rspec-rails'
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rake', require: false
  gem 'rubocop-rspec', require: false
  gem 'web-console'
end

group :test do
  gem 'capybara'
  gem 'capybara-screenshot'
  gem 'cucumber-rails', require: false
  gem 'database_cleaner'
  gem 'database_cleaner-active_record'
  gem 'launchy'
  gem 'n_plus_one_control'
  gem 'selenium-webdriver'
  gem 'shoulda-matchers'
  gem 'simplecov', require: false
end
