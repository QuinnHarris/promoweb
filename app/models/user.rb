require 'digest/sha1'

# this model expects a certain database layout and its based on the name/login pattern. 
class User < ActiveRecord::Base
  # Authorization plugin
  has_many :permissions, :dependent => :destroy
  has_many :delegatables, :dependent => :destroy
  belongs_to :current_order, :class_name => 'Order', :foreign_key => 'current_order_id'
  has_many :orders
  has_many :commissions

  def email
    self['email'] || (!new_record? && "#{login}@mountainofpromos.com")
  end

  def phone
    return self['phone'] if self['phone']
    return "970-375-1900 x#{extension}" if extension
    nil
  end

  # Please change the salt to something else, 
  # Every application should use a different one 
  @@salt = 'promoweb'
  cattr_accessor :salt

  # Authenticate a user. 
  #
  # Example:
  #   @user = User.authenticate('bob', 'bobpass')
  #
  def self.authenticate(login, pass)
    find(:first, :conditions => ["login = ? AND password = ?", login, sha1(pass)])
  end  

  def email_string
    "\"#{name} / Mountain Xpress Promotions\" <#{email}>"
  end
  
  def role
    perms = permissions.find_all_by_order_id(nil)
    return 'none' if perms.empty? and delegatables.to_a.empty?
    return 'super' if perms.find { |p| p.name == 'Super' }
    return 'orders' if perms.find { |p| p.name == 'Orders' }
    return 'artwork' if delegatables.to_a.find { |d| d.name = 'Art' }
    'special'
  end
  
  def role=(new_name)
    @role = new_name
  end
  
  after_save :save_role
  def save_role
    return nil unless @role
    old_name = role
    if old_name != @role
      raise "Can't change from special role" if old_name == 'special'
      User.transaction do
        permissions.clear
        delegatables.clear
  
        case @role
          when 'super'
            permissions.create(:name => 'Super')
          when 'orders'
            permissions.create(:name => 'Orders')
          when 'artwork'
            delegatables.create(:name => 'Art')
        end
      end
    end
  end

protected
  # Apply SHA1 encryption to the supplied password. 
  # We will additionally surround the password with a salt 
  # for additional security. 
  def self.sha1(pass)
    Digest::SHA1.hexdigest("#{salt}--#{pass}--")
  end
    
  before_create :crypt_password
  
  # Before saving the record to database we will crypt the password 
  # using SHA1. 
  # We never store the actual password in the DB.
  def crypt_password
    write_attribute "password", self.class.sha1(password)
  end
  
  before_update :crypt_unless_empty
  
  # If the record is updated we will check if the password is empty.
  # If its empty we assume that the user didn't want to change his
  # password and just reset it to the old value.
  def crypt_unless_empty
    if password_changed?
      write_attribute "password", self.class.sha1(password)
    end        
  end  
  
  validates_uniqueness_of :login, :on => :create

  validates_length_of :login, :within => 3..40
  validates_presence_of :login
end

class UserPass < User
  validates_presence_of :password, :password_confirmation
  validates_confirmation_of :password
  validates_length_of :password, :within => 5..40
end
