module PhoneHelper
  def user_phones_path(*args)
    admin_user_phones_path(*args)
  end

  def user_path(*args)
    admin_user_path(*args)
  end
end
