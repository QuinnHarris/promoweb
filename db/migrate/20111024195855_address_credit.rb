class AddressCredit < ActiveRecord::Migration
  def self.up
    logger.info("Consolidate Payments")
    pms = PaymentCreditCard.all
    pms.each do |pm|
      unless pm.display_number.blank?
        pm.display_number = pm.display_number.split('-').last
        pm.save!
      end
    end

    pms.group_by { |p| [p.customer_id, p.display_number, p.name] }.each do |key, methods|
      next if methods.length == 1
      methods.sort_by! { |m| m.id }
      keep = methods.first
      methods[1..-1].each do |m|
        m.transactions.each do |t|
          t.method_id = keep.id
          t.save!
        end
        m.destroy
      end
      
      puts key.inspect
    end
  end

  def change
    add_column :payment_methods, :sub_type, :string, :limit => 18

    add_column :payment_transactions, :auth_code, :string, :limit => 16
    add_column :payment_transactions, :invoice_id, :integer
    add_foreign_key :payment_transactions, :invoices

    add_column :orders, :purchase_order, :string, :limit => 32
    
    rename_column :addresses, :address_1, :address1
    rename_column :addresses, :address_2, :address2
    add_column    :addresses, :country, 'char(2)', :default => 'US'
  end
end
