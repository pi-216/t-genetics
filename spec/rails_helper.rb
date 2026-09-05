# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)

abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'spec_helper'
require 'rspec/rails'
require 'view_component/test_helpers'

ActiveJob::Base.queue_adapter = :test

Rails.root.glob('spec/support/*.rb').each { |f| require f }

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include ActiveJob::TestHelper
  # PRD-0004: component specs (spec/components/*_spec.rb) render ViewComponents
  # inline via the gem's test helpers.
  config.include ViewComponent::TestHelpers, type: :component
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
