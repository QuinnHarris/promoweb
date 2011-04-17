class StandardColors < ActiveRecord::Migration
  def self.up
    add_column :suppliers, :standard_colors, :text
  end

  def self.down
  end
end
