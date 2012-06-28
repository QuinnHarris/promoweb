class CallsDetails < ActiveRecord::Migration
  def change
    change_table :call_logs do |t|
      CallLog.rtp_stat_names.each do |name|
        t.integer name, :default => 0, :null => false
      end
    end
  end
end
