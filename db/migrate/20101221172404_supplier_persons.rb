class SupplierPersons < ActiveRecord::Migration
  def self.up
    %w(inside_sales accounting customer_service problem_resolution).each do |name|
      %w(name email).each do |field|
        add_column :suppliers, "#{name}_#{field}", :string
      end
      add_column :suppliers, "#{name}_phone", :bigint
    end

    add_column :suppliers, :credit, :integer, :default => 0, :null => false
  end

  def self.down
  end
end
