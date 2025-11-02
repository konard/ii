source "https://rubygems.org"

ruby "~> 3.3.0"

# Rails 8
gem "rails", "~> 8.0.0"

# Database
gem "sqlite3", ">= 2.1"

# HTTP client
gem "faraday", "~> 2.10"
gem "faraday-retry"

# Asset pipeline
gem "propshaft"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"

# Background jobs (Solid Queue - Rails 8 default)
gem "solid_queue"

# Use the Puma web server
gem "puma", ">= 6.0"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

group :development, :test do
  # Debugging
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities
  gem "brakeman", require: false

  # Omakase Ruby styling
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages
  gem "web-console"
end

group :test do
  # Use system testing
  gem "capybara"
  gem "selenium-webdriver"
end
