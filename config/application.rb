require File.expand_path('../boot', __FILE__)

require 'rails/all'

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require *Rails.groups(:assets => %w(development test))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

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

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    # config.active_record.whitelist_attributes = true
    
    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    # Load SASS/Compass plugins
#    unless Rails.env.production?
#      config.sass.load_paths << "#{Gem.loaded_specs['fancy-buttons'].full_gem_path}/stylesheets"
#    end

#    config.wash_out = { :parser => :nokogiri }
  end
end

require "#{Rails.root}/lib/mymoney"

# GeoIP geoip-c gem
require 'geoip'
GEOIP = GeoIP::City.new('/usr/share/GeoIP/GeoLiteCity.dat')

# Use Nokogiri for soap4r used https://github.com/spox/soap4r-spox (for ruby 1.9 support)
#require 'xsd/xmlparser'
#require 'xsd/xmlparser/nokogiri'

# From rails 3.1 to make action_web_services work
require "#{Rails.root}/lib/inheritable_attributes"

SITE_NAME = "www.mountainofpromos.com"
MAIN_EMAIL = 'sales@mountainofpromos.com'

COMPANY_NAME_SHORT = 'Mountain Express Promotions'
COMPANY_NAME = "#{COMPANY_NAME_SHORT}, LLC"
COMPANY_ADDRESS = "361 S. Camino Del Rio, Ste 160\nDurango, CO 81301"

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


# Extensions to bitcoin-client library
class Bitcoin::Client
  def getpeerinfo
    @api.request 'getpeerinfo'
  end

  def encryptwallet(passphrase)
    @api.request 'encryptwallet', passphrase
  end

  def keypoolrefill
    @api.request 'keypoolrefill'
  end

  def walletlock
    @api.request 'walletlock'
  end

  def walletpassphrase(passphrase, timeout)
    @api.request 'walletpassphrase', passphrase, timeout
  end
end


class BitCoinRate
  def initialize(file, url)
    @file = file
    @uri = URI.parse(url)
    @cache = {}
  end

  def get_hash(age = 20.minutes)
    return @hash if @mtime and @mtime > (Time.now - age)
    @mtime = @hash = nil
    @cache = {}
    unless File.exists?(@file)
      Rails.logger.warn("BitCoin Rate file does not exist: #{@file}")
    else
      @mtime = File.mtime(@file)
      unless @mtime > (Time.now - age)
        Rails.logger.warn("BitCoin Rate file out of date: (#{age}) #{@mtime} : #{@file}")
        @mtime = nil
      end
    end

    data = nil

    unless @mtime
      begin
        start = Time.now
        Net::HTTP.start(@uri.host, @uri.port, nil, nil, nil, nil, :open_timeout => 2, :read_timeout => 2) do |http|
          data = http.request_get(@uri.path).body
          File.open(@file, 'w') { |f| f.write(data) }
        end
        Rails.logger.info("BitCoin Rate file fetched: #{@file} : #{@uri} : #{Time.now - start}")
        @mtime = File.mtime(@file)
      rescue 
        # Rescue errors on bitcoin website
        Rails.logger.error("Could not get bitcoin rate: #{@uri}")
        @mtime = Time.now - age/2 # Retry latter
      end
    end

    unless data
      Rails.logger.info("BitCoin Rate file reloaded: #{@mtime} : #{@file}")
      f = File.open(@file)
      data = f.read
    end

    @hash = ActiveSupport::JSON.decode(data)
  end

  def age
    Time.now - @mtime
  end

  def rate_USD(age = 20.minutes)
    get_hash(age)
    return @cache['rate_USD'] if @cache['rate_USD']
    @cache['rate_USD'] = rate_USD_internal
  end

  def self.bc_USD(rate, usd)
    digits = (Math.log(rate.to_f)/Math.log(10)).ceil + 2
    (usd.to_f / rate.to_f).round(digits)
  end

  def bc_USD(usd, age = 20.minutes)
    rate = rate_USD(age)
    @cache['digits_USD'] = (Math.log(rate.to_f)/Math.log(10)).ceil + 2 unless @cache['digits_USD']
    (usd.to_f / rate.to_f).round(@cache['digits_USD'])
  end

  def self.usd_BC(rate, coin)
    Money.new(rate) * coin
  end
end

class BitCoinChartsRate < BitCoinRate
  def initialize(file)
    super file, 'http://api.bitcoincharts.com/v1/weighted_prices.json'
  end

  def rate_USD_internal
    Money.new(Float(@hash['USD']['24h']))
  end
end

class BitCoinAverageRate < BitCoinRate
  def initialize(file)
    super file, 'http://api.bitcoinaverage.com/ticker/global/USD/'
  end

  def rate_USD_internal
    Money.new(Float(@hash['24h_avg']))
  end
end

BCRate = BitCoinAverageRate.new('/tmp/weighted_prices_avarage.json')
BCDiscount = 5.0
