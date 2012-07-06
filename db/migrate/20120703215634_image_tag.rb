class ImageTag < ActiveRecord::Migration
  def change
    change_table :product_images do |t|
      t.string :tag, :length => 16
    end
  end
end
