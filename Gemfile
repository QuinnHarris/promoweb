if RUBY_VERSION =~ /1.9/
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

source 'http://rubygems.org'

gem 'rails', '3.2.3'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'

gem 'pg'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier',     '>= 1.0.3'

  gem 'compass-rails'
  gem 'fancy-buttons'

  gem 'therubyracer'
end

gem 'jquery-rails'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger (ruby-debug for Ruby 1.8.7+, ruby-debug19 for Ruby 1.9.2+)
# gem 'ruby-debug'
group :development do
#  gem 'ruby-debug19', :require => 'ruby-debug'
  gem 'ruby-prof'
  
  # Use unicorn as the web server
  gem 'unicorn'
end

group :test do
  # Pretty printed test output
  gem 'turn', :require => false
end

# Bundle the extra gems:
# gem 'bj'
# gem 'aws-s3', :require => 'aws/s3'
gem 'nokogiri'
gem 'haml'
#gem 'sass'
gem 'activemerchant'
gem 'foreigner'
gem 'acts_as_tree'
gem 'will_paginate'
gem 'paperclip' #, "= 2.3.16"
gem 'rghost'
gem 'exception_notification'
#gem 'exifr'
gem 'awesome_nested_set'
gem 'dynamic_form'
#gem 'pg_search'
gem 'scruffy'
gem 'geoip-c'
gem 'wicked_pdf'
gem 'fast_xs'
gem 'rails_autolink'
gem 'rails3-jquery-autocomplete'
#gem 'jquery-fileupload-rails'

#gem 'actionwebservice', :git => 'https://github.com/jlecard/actionwebservice.git'

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
