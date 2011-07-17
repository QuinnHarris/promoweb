module Admin::PhoneHelper
  def format_time_tod(time)
    time.strftime(" %I:%M:%S %p")
  end
end
