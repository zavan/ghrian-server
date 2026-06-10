require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Server
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Let the Active Record Encryption keys come from the environment so the
    # published image is self-serve: anyone can run it with their own keys (plus
    # SECRET_KEY_BASE, which Rails already reads from the env) and no shared
    # master.key. Falls back to encrypted credentials when these aren't set.
    if ENV["AR_ENCRYPTION_PRIMARY_KEY"].present?
      config.active_record.encryption.primary_key = ENV["AR_ENCRYPTION_PRIMARY_KEY"]
      config.active_record.encryption.deterministic_key = ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]
      config.active_record.encryption.key_derivation_salt = ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]
    end
  end
end
