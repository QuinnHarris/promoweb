source 'http://rubygems.org'

gem 'rails', '3.1.1'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'

gem 'pg'


# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', "  ~> 3.1.0"
  gem 'coffee-rails', "~> 3.1.0"
  gem 'uglifier'
end

# Remove soon
gem 'prototype-rails', :git => 'git://github.com/rails/prototype-rails.git'
#gem 'jquery-rails'

# Use unicorn as the web server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger (ruby-debug for Ruby 1.8.7+, ruby-debug19 for Ruby 1.9.2+)
# gem 'ruby-debug'
group :development do
  gem 'ruby-debug19', :require => 'ruby-debug'
  gem 'ruby-prof'
end

group :test do
  # Pretty printed test output
  gem 'turn', :require => false
end

# Bundle the extra gems:
# gem 'bj'
# gem 'aws-s3', :require => 'aws/s3'
gem "compass", ">= 0.12.alpha.0"
gem "fancy-buttons"
gem 'nokogiri'
#gem 'uuidtools'
gem 'haml'
#gem 'coffee-rails'
gem 'activemerchant'
gem 'foreigner'
gem 'acts_as_tree'
gem 'will_paginate'
gem 'paperclip'
gem 'rghost'
gem 'exception_notification'
#gem 'exifr'
gem 'nested_set'
gem 'dynamic_form'
#gem 'pg_search'
gem 'scruffy'
gem 'geoip-c'
gem 'wicked_pdf'
gem 'fast_xs'
gem 'rails_autolink'

# Not needed for webserver
gem 'mechanize' # DL for Gemline
gem 'spreadsheet' # Spreadsheet for Leeds, Bullet
#gem 'httpclient' # Auth for soap4r for Lanco
gem 'savon'
gem 'rmagick'

# Bundle gems for the local environment. Make sure to
# put test-only gems in this group so their generators
# and rake tasks are available in development mode:
group :development, :test do
  gem 'silent-postgres'
#   gem 'webrat'
end
