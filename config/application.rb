require File.expand_path('../boot', __FILE__)

require 'rails/all'

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env) if defined?(Bundler)

module Promoweb
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/extras)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # JavaScript files you want as :defaults (application.js is always included).
    # config.action_view.javascript_expansions[:defaults] = %w(jquery rails)

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]
  end
end

require "#{Rails.root}/lib/mymoney"

# GeoIP geoip-c gem
require 'geoip'
GEOIP = GeoIP::City.new('/usr/share/GeoIP/GeoLiteCity.dat')

# Use Nokogiri for soap4r used https://github.com/spox/soap4r-spox (for ruby 1.9 support)
require 'xsd/xmlparser'
require 'xsd/xmlparser/nokogiri'

MAIN_EMAIL = 'sales@mountainofpromos.com'

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
