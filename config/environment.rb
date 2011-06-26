# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.12' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

require 'mymoney'

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Specify gems that this application depends on and have them installed with rake gems:install
  # config.gem "bj"
  # config.gem "hpricot", :version => '0.6', :source => "http://code.whytheluckystiff.net"
  # config.gem "sqlite3-ruby", :lib => "sqlite3"
  # config.gem "aws-s3", :lib => "aws/s3"
#  config.gem 'money'
  config.gem 'uuidtools'
  config.gem 'haml'
  config.gem 'sass'
  config.gem 'activemerchant', :lib => 'active_merchant'
  config.gem 'foreigner', :version => '= 0.9.2'
  config.gem 'acts_as_tree'
  config.gem 'will_paginate', :version => '~> 2.3.11', :source => 'http://gemcutter.org'
  config.gem 'paperclip', :version => '~> 2.3'
  config.gem 'nokogiri'
  
  # Only load the plugins named here, in the order given (default is alphabetical).
  # :all can be used as a placeholder for all plugins not explicitly named
  # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

  # Skip frameworks you're not going to use. To use Rails without a database,
  # you must remove the Active Record framework.
  # config.frameworks -= [ :active_record, :active_resource, :action_mailer ]

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

  # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
  # Run "rake -D time" for a list of tasks for finding time zone names.
  config.time_zone = 'UTC'

  # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
  # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}')]
  # config.i18n.default_locale = :de

  # Your secret key for verifying cookie session data integrity.
  # If you change this key, all old sessions will become invalid!
  # Make sure the secret is at least 30 characters and all random, 
  # no regular words or you'll be exposed to dictionary attacks.
  secrets = YAML.load_file(RAILS_ROOT + '/config/secrets')
  config.action_controller.session = {
    :key => "_promoweb_session",
    :secret      => secrets['session']['secret'],
    :cookie_only => true
  }

  # Activate observers that should always be running
#  config.active_record.observers = :product_sweeper
end

#require 'action_web_service'

# Add new inflection rules using the following format 
# (all these examples are active by default):
ActiveSupport::Inflector.inflections do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   inflect.irregular 'person', 'people'
#   inflect.uncountable %w( fish sheep )
  inflect.irregular 'category', 'categories'
end

# Add new mime types for use in respond_to blocks:
# Mime::Type.register "text/richtext", :rtf
# Mime::Type.register "application/x-mobile", :mobile

# Include your application configuration below
require 'uuid22'
require 'shipping'
require 'access_parser'
require 'pdf_helper'
require 'pantone'

require 'net/geoip'
GEOIP = Net::GeoIP.new("/usr/share/GeoIP/GeoLiteCity.dat")

MAIN_EMAIL = 'sales@mountainofpromos.com'

#CGI::Session.expire_after 1.month

# Hack from https://rails.lighthouseapp.com/projects/8995/tickets/85-exception_notification-2330-fails-with-rails-235
ExceptionNotification::Notifier.view_paths = ActionView::Base.process_view_paths(ExceptionNotification::Notifier.view_paths)

# Active Record extention used in order controller (Remove sometime)
class ActiveRecord::Base
  def update_attributes?(attributes)
    attributes.find do |a, v|
      column_for_attribute(a).type_cast(v) != read_attribute(a)
    end
  end
end


class Time
  def add_workday(duration)
    duration = duration.to_i
    time = self.dup
    begin
    # If this is on the weekend advance to the beginning of the week
      unless (1..5).member?(time.wday)
        time = time.beginning_of_day + 8.hours
        time += 1.day until (1..5).member?(time.wday)
      end
      
      while time + duration > (eow = (time + (5 - time.wday).days).end_of_day)
        duration -= (eow - time).to_i
        time = (eow + 3.days).beginning_of_day
      end
      time += duration

    rescue
    end
    time
  end
end

class Date
  def add_workday(days)
    # If this is on the weekend advance to the beginning of the week
    date = self.dup
    date += 1.day until (1..5).member?(date.wday)

    while date + days > (eow = (date + (5 - date.wday)))
      days -= (eow - date)
      date = (eow + 3)
    end
    date += days
    date
  end
end
