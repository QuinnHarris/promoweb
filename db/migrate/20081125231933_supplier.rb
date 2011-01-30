class Supplier < ActiveRecord::Migration
  def self.up
    add_column :suppliers, :address_id, :integer
    add_column :suppliers, :artwork_email, :string
    add_column :suppliers, :po_email, :string
    add_column :suppliers, :fax, :string
    
    rename_column :artworks, :comment, :customer_notes
    add_column :artworks, :our_notes, :text
    
    #add_column :artwork_order_tag, :purchase_order_id, :integer
  end

  def self.down
    remove_column :suppliers, :address_id
    remove_column :suppliers, :artwork_email
    remove_column :suppliers, :po_email
    remove_column :suppliers, :fax
    
    rename_column :artworks, :customer_notes, :comment
    remove_column :artworks, :our_notes
    
    #remove_column :artwork_order_tag, :purchase_order_id
  end
end
