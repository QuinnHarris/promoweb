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
    self['uuid'] = [SecureRandom.random_bytes(17)].pack("m*").delete("\n").to(21).gsub('/','_').gsub('+', '-')
    self.quickbooks_id = 'BLOCKED'
  end
  
  def self.uuid_authenticate(id)
    find_first(["uuid = ?", id])
  end
    
  def email_string
    email_addresses.collect { |e| "\"#{person_name}\" <#{e.address}>" }
  end

  def sales_tax
    if default_address &&
        (default_address.state.downcase == 'colorado' ||
         default_address.state.downcase == 'co')
# No Durango Tax License
#      if default_address.city.downcase == 'durango'
#        return ['Durango', 0.079]
      if [81301, 81303, 81122, 81137, 81326].include?(default_address.postalcode.to(4).to_i)
        return ['LaPlata', 0.049]
      else
        return ['Colorado', 0.029]
      end
    end
    [nil, 0.0]
  end

  before_destroy :remove_contacts
  def remove_contacts
    phone_numbers.each { |pn| pn.destroy }
    email_addresses.each { |ea| ea.destroy }
    shipping_rates.each { |sr| sr.destroy }
    (tasks_active+tasks_inactive+tasks_other).each { |t| t.destroy }
  end
end
