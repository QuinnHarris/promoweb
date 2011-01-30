class CreateArtworks < ActiveRecord::Migration
  def self.up
    create_table :artworks do |t|
      t.column :customer_id, :integer, :null => false
      t.column :name, :string
      t.column :file, :string
      t.column :comment, :text
      t.column :created_at,   :datetime, :null => false
      t.column :updated_at,   :datetime, :null => false
    end
    
    remove_column :order_item_decorations, :image
    add_column :order_item_decorations, :artwork_id, :integer
  end

  def self.down
    add_column :order_item_decorations, :image, :text
    remove_column :order_item_decorations, :artwork_id
    
    drop_table :artworks
  end
end
