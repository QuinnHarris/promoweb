class CreateProductImages < ActiveRecord::Migration
  def self.up
    create_table :product_images do |t|
      t.references :product, :null => false
      t.string :supplier_ref
      t.timestamps
    end

    create_table :product_images_variants, :id => false do |t|
      t.references :product_image, :null => false
      t.references :variant, :null => false
    end
  end

  def self.down
    drop_table :product_image_variants
    drop_table :product_images
  end
end
