source "https://rubygems.org"

gem "rails", "~> 8.1.4"
gem "propshaft"
gem "mysql2", "~> 0.5"
gem "puma", ">= 5.0"

gem "devise", "~> 5.0"
gem "omniauth-google-oauth2"
gem "omniauth-facebook"
gem "omniauth-github"
gem "omniauth-rails_csrf_protection"

gem "acts-as-taggable-on", "~> 13.0"
gem "caxlsx", "~> 4.0"
gem "csv"
gem "hairtrigger"
gem "redcarpet"
gem "rails-i18n"
gem "view_component", "~> 4.23"

gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

# Ruby 4.0 no longer ships fiddle as a default gem, but reline/IRB still need it.
gem "fiddle"
# Hairtrigger uses OpenStruct, which is no longer a default gem in Ruby 4.0.
gem "ostruct"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
end

group :development do
  gem "web-console"
end
