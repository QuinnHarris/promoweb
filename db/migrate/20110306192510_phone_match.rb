class PhoneMatch < ActiveRecord::Migration
  def self.up
    add_column :users, :incoming_phone_number, :string
    add_column :users, :incoming_phone_name, :string
    add_column :users, :incoming_phone_time, :timestamp

    # Add to access area_code
    #ALTER table session_accesses ADD area_code INTEGER;
    #CREATE INDEX session_access_area_code ON session_accesses ( area_code, updated_at );
  end

  def self.down
  end
end
