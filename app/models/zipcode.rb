class Zipcode < ActiveRecord::Base
  establish_connection("constants")

  def tz_name
    case timezone
      when -10
        'Hawaii'
      when -9
        'Alaska'
      when -8
        'Pacific Time (US & Canada)'
      when -7
        'Mountain Time (US & Canada)'
      when -6
        'Central Time (US & Canada)'
      when -5
        'Eastern Time (US & Canada)'
    end
  end
end
