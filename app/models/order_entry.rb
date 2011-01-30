class OrderEntry < ActiveRecord::Base
  belongs_to :order
  has_many :invoice_entries, :class_name => 'InvoiceOrderEntry', :foreign_key => 'entry_id', :conditions => "type = 'InvoiceOrderEntry'"

  %w(price cost).each do |name|
    composed_of name.to_sym, :class_name => 'Money', :mapping => [name, 'units']
    alias_method "list_#{name}", name
    define_method "total_#{name}" do
      send(name) * quantity
    end
  end
  
  def invoice_description
    description
  end
end
