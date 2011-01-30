class ExtendSupplier < ActiveRecord::Migration
  def self.up
    # General Decoration
    DecorationTechnique.create(:name => 'General')
    remove_column :order_item_decorations, :artwork_id
    add_column :order_item_decorations, :description, :text

    # suppliers
    add_column :purchase_orders, :supplier_id, :integer

    [:fax, :phone].each do |name|
      remove_column :suppliers, name
      add_column :suppliers, name, :integer, :limit => 8
    end
    change_column :suppliers, :price_source_id, :integer, :null => true
    rename_column :suppliers, :headline, :description
    add_column :suppliers, :parent_id, :integer, :references => :suppliers
    add_column :suppliers, :po_note, :string
    execute "ALTER TABLE suppliers DROP CONSTRAINT name_suppliers"
    execute "ALTER TABLE suppliers ADD CONSTRAINT name_suppliers UNIQUE(parent_id, name)"

    norwood = Supplier.find_by_name('Norwood')
    norwood.po_email = '100credit@norwood.com'
    norwood.phone = 8665639922
    norwood.fax = 8666823374
    norwood.save!

    address = Address.create(:address_1 => '5151 Moundview Drive',
                             :city => 'Red Wing',
                             :state => 'MN',
                             :postalcode => '55066')
    [['Barlow', 'Auto, Tools & flashlights'],
     ['TeeOff', 'Golf, Sports & Fun'],
     ['Pillow', 'Health, Wellneww & Safety'],
     ['EOL', 'Office, Magnets & Badge Holders']].each do |name, desc|
      norwood.children.create(:name => name,
                              :description => desc,
                              :po_email => 'rworders@norwood.com',
                              :artwork_email => 'rwart@norwood.com',
                              :phone => 8008003372,
                              :fax => 8007702012,
                              :address => address,
                              :quickbooks_id => 'NO UPDATE')
    end
    norwood.children.create(:name => 'Souvenir',
                            :description => 'Writing Instruments',
                            :po_email => 'souvenirmail@norwood.com',
                            :artwork_email => 'souvenirart@norwood.com',
                            :phone => 8008003372,
                            :fax => 8007702012,
                            :address => address,
                            :quickbooks_id => 'NO UPDATE')    


    address = Address.create(:address_1 => '5335 Castroville Road',
                             :city => 'San Antonio',
                             :state => 'TX',
                             :postalcode => '78227')
    [['RCC', 'Drinkware & Housewares'],
     ['AirTex', 'Bags, Meeting & Outdoor']].each do |name, desc|
      norwood.children.create(:name => name,
                              :description =>  desc,
                              :po_email => 'rworders@norwood.com',
                              :artwork_email => 'rwart@norwood.com',
                              :phone => 8008003372,
                              :fax => 8007702012,
                              :address => address,
                              :quickbooks_id => 'NO UPDATE')
    end
    norwood.children.create(:name => 'Global Sourcing',
                            :po_email => 'custom@norwood.com',
                            :artwork_email => 'custom@norwood.com',
                            :phone => 8775473401,
                            :fax => 8883162486,
                            :address => address,
                            :quickbooks_id => 'NO UPDATE') 

    address = Address.create(:address_1 => '1000 Highway 4 South',
                             :city => 'Sleepy Eye',
                             :state => 'MN',
                             :postalcode => '56085')
    [['GOODVALU', 'Good Value Calendars'],
     ['TRIUMPH', 'Calendars, Planners & Diaries']].each do |name, desc|
      norwood.children.create(:name => name,
                              :description => desc,
                              :po_email => 'seorders@norwood.com',
                              :artwork_email => 'triumph@norwood.com',
                              :phone => (name == 'Custom') ? 8003369198 : 5077948100,
                              :fax => 5077948100,
                              :address => address,
                              :quickbooks_id => 'NO UPDATE')
    end                              

    address = Address.create(:address_1 => '1309 Plainfield Avenue',
                             :city => 'Janesville',
                             :state => 'WI',
                             :postalcode => '53545')
    norwood.children.create(:name => 'Jaffa',
                            :description => 'Awards, Recognition & Gifts',
                            :po_email => 'jaffaorders@norwood.com',
                            :artwork_email => 'jaffaart@norwood.com',
                            :phone => 8007845242,
                            :fax => 6087566931,
                            :address => address,
                            :quickbooks_id => 'NO UPDATE')

    
    gemline = Supplier.find_by_name('Gemline')
    gemline.update_attributes!(:fax => 9786912085, :artwork_email => 'art@gemline.com')
    gemline.children.create(:name => 'FastShip',
                            :artwork_email => 'fasttrack@gemline.com',
                            :fax => 9789890123)

    leeds = Supplier.find_by_name('Leeds')
    leeds.update_attributes!(:fax => 8008606661, :artwork_email => 'art@leedsworld.com')
    leeds.children.create(:name => 'SureShip',
                          :artwork_email => 'sureshipart@leedsworld.com',
                          :fax => 8006114731)
  end

  def self.down
    remove_column :suppliers, :parent_id
    execute "ALTER TABLE suppliers DROP CONSTRAINT name_suppliers"
    execute "ALTER TABLE suppliers ADD CONSTRAINT name_suppliers UNIQUE(name)"
  end
end
