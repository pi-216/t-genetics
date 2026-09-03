require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TGenetics
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))
    config.assets.css_compressor = nil

    # Autoload bounded-context code from packs/<context>/app/* so Rails can load
    # it (root = e.g. packs/identity/app/models → models/identity/user.rb
    # → Identity::User) and Packwerk can attribute constants to their owning pack.


    Dir[Rails.root.join("packs/*/app/*")].sort.each do |pack_app_dir|
      config.autoload_paths << pack_app_dir
      config.eager_load_paths << pack_app_dir
    end

    # Register pack view dirs so controllers in packs can render their views.
    Dir[Rails.root.join("packs/*/app/views")].each do |pack_views_dir|
      config.paths["app/views"].push(pack_views_dir)
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
