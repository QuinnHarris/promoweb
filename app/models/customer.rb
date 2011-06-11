class Customer < ActiveRecord::Base  
  has_many :orders, :order => "id DESC"
  has_many :artwork_groups, :order => 'id DESC'
  
  # Tasks
  OrderTask
  include ObjectTaskMixin
  has_tasks
  def tasks_context
    tasks_active.to_a
  end
  
  belongs_to :default_address, :class_name => 'Address', :foreign_key => 'default_address_id'
  belongs_to :ship_address, :class_name => 'Address', :foreign_key => 'ship_address_id'
  belongs_to :bill_address, :class_name => 'Address', :foreign_key => 'bill_address_id'
  has_many :phone_numbers
  accepts_nested_attributes_for :phone_numbers, :allow_destroy => true, :reject_if => :all_blank

  has_many :email_addresses
  accepts_nested_attributes_for :email_addresses, :allow_destroy => true, :reject_if => :all_blank

  has_many :payment_methods, :order => 'id DESC'
  has_many :shipping_rates
  def shipping_rates_clear!
    shipping_rates.each do |sr|
      sr.destroy
    end
  end
  
  validates_presence_of :person_name

  def empty?
    company_name == '' and
    person_name == ''
  end
  
  before_save :strip_name
  def strip_name
    self.company_name = company_name.strip
    self.person_name = person_name.strip
    true
  end
  

  before_create :set_uuid
  def set_uuid
    self['uuid'] = UUIDTools::UUID.random_create.to_s22
    self.quickbooks_id = 'BLOCKED'
  end
  
  def self.uuid_authenticate(id)
    find_first(["uuid = ?", id])
  end
    
  def email_string
    email_addresses.collect { |e| "\"#{person_name}\" <#{e}>" }
  end

  def sales_tax
    if default_address &&
        (default_address.state.downcase == 'colorado' ||
         default_address.state.downcase == 'co')
      return ['Colorado', 0.029]
    end
    [nil, 0.0]
  end
end

#class CustomerValidate < Customer
#  validates_presence_of :person_name, :email, :phone
#  validates_as_email :email
#  
##  def self.valid_phone?(number)
##    return true if number.nil?
##
##    n_digits = number.scan(/[0-9]/).size
##    valid_chars = (number =~ /^[+\/\-() 0-9]+$/)
##    return n_digits == 10 && valid_chars
##  end    
##  
##  def validate
##    error_message = 'is an invalid phone number, must contain 10 digits, only the following characters are allowed: 0-9/-()+'
##    
##    return true if phone.nil?
##    
##    digits = phone.scan(/[0-9]/)
##    valid_chars = (phone =~ /^[+\/\-() 0-9]+$/)
##
##    if digits.size == 10 && valid_chars
##      phone = digits.join
##      return true
##    else
##      errors.add('phone', error_message)  
##      return false    
##    end
##  end
#end

#Customer.establish_connection(RAILS_ENV + '_orders')
