require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module InventoryManagement
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.generators.system_tests = nil

    config.i18n.available_locales = %i[en pl]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = [:en]
    config.time_zone = "Europe/Warsaw"

    config.x.cloudinary_cloud_name = ENV["CLOUDINARY_CLOUD_NAME"]
    config.x.cloudinary_upload_preset = ENV["CLOUDINARY_UPLOAD_PRESET"]
  end
end
