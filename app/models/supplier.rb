class Supplier < ActiveRecord::Base
  acts_as_tree
  has_many :products, :conditions => 'NOT(deleted)'
  has_many :decoration_price_groups
  belongs_to :price_source
  has_many :warehouses
  belongs_to :address

  before_save :strip_name
  def strip_name
    self.name.strip!
  end

  def standard_colors
    attributes['standard_colors'] ? attributes['standard_colors'].split(',') : (parent ? parent.standard_colors : nil)
  end

  validates_numericality_of :phone, :fax, :allow_nil => true
#  validates_as_email :artwork_email, :po_email

  def id_list
    [id] + ((parent && parent.id_list) || [])
  end

  # Bug if same technique in parent supplier
  def find_decoration_price_group(technique)
    technique.price_groups.find_by_supplier_id(id_list)
  end
  
  def get_product(num)
    prod = Product.find_by_supplier_id_and_supplier_num(id, num)
    prod = Product.new({
      :supplier => self,
      :supplier_num => num
    }) unless prod
    prod
  end

  def name
    [parent && parent.name, attributes['name']].compact.join(' ')
  end

  %w(quickbooks_id quickbooks_sequence price_source_id address_id artwork_email po_email fax phone account_number web).each do |name|
    define_method(name) do
      unless (val = attributes[name]).blank?
        next val
      end
      next nil unless parent
      parent.send(name)
    end
  end

  %w(price_source address).each do |name|
    alias_method "#{name}_orig", name
    define_method(name) do
      if val = send("#{name}_orig")
        next val
      end
      next nil unless parent
      parent.send(name)
    end
  end

  def fax?
    po_email.blank?
  end

  def send_email(sample = false)
    (sample && !samples_email.blank?) ? samples_email : po_email
  end

  def include_artwork_with_po?
    artwork_email == po_email
  end
end
