class CreateKeywords < ActiveRecord::Migration
  def self.up
    create_table :keywords do |t|
      t.column :phrase, :string
    end
    
    create_table :categories_keywords, :id => false do |t|
      t.column :category_id, :integer, :null => false
      t.column :keyword_id, :integer, :null => false
      t.column :name,  :string
    end
  end

  def self.down
  end
end
