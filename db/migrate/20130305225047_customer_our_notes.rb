class CustomerOurNotes < ActiveRecord::Migration
 def change
    change_table :customers do |t|
      t.text :our_notes
    end
  end
end
