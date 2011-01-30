class ArtSentOrderTask < OrderTask
  set_depends_on [FirstPaymentOrderTask, PaymentOverrideOrderTask, PaymentNoneOrderTask], ArtAcknowledgeOrderTask
  self.status_name = 'Artwork to Supplier'
  self.waiting_name = 'Send Artwork to Supplier'
  self.completed_name = 'Artwork Sent to Supplier'
  self.action_name = 'Send artwork to supplier'
  
  def self.blocked(order)
    super || (order.artwork_tags.find_by_name('supplier') ? nil : "An image must be marked as a Supplier before it can be sent to the supplier!")
  end
  
#  def admin
#    true
#  end
end

class ArtExcludeOrderTask < OrderTask
  # Don't suggest this task
  self.status_name = 'Artwork Excluded'
  self.completed_name = 'Artwork Excluded'
  self.action_name = 'mark as <strong>no artwork required</strong> for this order'
  
  def self.blocked(object)
    super || (object.tasks_active.to_a.find { |t| t.is_a?(ArtReceivedOrderTask) } && "artwork already received")
  end
  
  def admin
    !new_record? and active
  end
end


class CreateArtworkGroups < ActiveRecord::Migration
  def self.up
    create_table :artwork_groups do |t|
      t.string :name
      t.text :description
      t.integer :customer_id, :null => false
      t.timestamps
    end
    execute "ALTER TABLE artwork_groups ADD CONSTRAINT artwork_groups_name_customer UNIQUE(name, customer_id)"

    add_column :artworks, :group_id, :integer, :references => :artwork_groups
    add_column :order_item_decorations, :artwork_group_id, :integer
    add_column :order_item_decorations, :our_notes, :text

    # Cleanup Extra Artworks
    execute "DELETE FROM artwork_order_tags WHERE artwork_id IN (SELECT id FROM (SELECT min(id) AS id, count(*) AS count, customer_id, file FROM artworks GROUP BY customer_id, file) AS sub WHERE count > 1)"
    execute "DELETE FROM artworks WHERE id IN (SELECT id FROM (SELECT min(id) AS id, count(*) AS count, customer_id, file FROM artworks GROUP BY customer_id, file) AS sub WHERE count > 1)"

    groups = {}
    Artwork.find(:all).each do |artwork|
      group = groups[artwork.customer_id] || groups[artwork.customer_id] = ArtworkGroup.create(:name => 'Default', :customer_id => artwork.customer_id)
      Artwork.update_all("group_id = #{group.id}", "id = #{artwork.id}")
#      artwork.group = group
#      puts artwork.inspect
#      artwork.save!
    end
    
    change_column :artworks, :group_id, :integer, :null => false
    remove_column :artworks, :customer_id

    execute "ALTER TABLE artworks ADD CONSTRAINT artworks_file_group_id UNIQUE(file, group_id);"

    
    # Replace artwork_order_tags with artwork_tags
    create_table :artwork_tags do |t|
      t.string :name
      t.integer :artwork_id, :null => false
    end
    execute "ALTER TABLE artwork_tags ADD CONSTRAINT artwork_tags_artwork_name UNIQUE(name, artwork_id)"

    execute "INSERT INTO artwork_tags (name, artwork_id) SELECT DISTINCT name, artwork_id FROM artwork_order_tags"
    drop_table :artwork_order_tags


    [[ArtSentOrderTask, ArtSentItemTask],
     [ArtExcludeOrderTask, ArtExcludeItemTask]].each do |src, dst|
      src.find(:all).each do |task|
        task.object.items.each do |item|
          dst.create(:object => item,
                     :created_at => task.created_at,
                     :updated_at => task.updated_at,
                     :user_id => task.user_id,
                     :data => task.data,
                     :host => task.host,
                     :active => task.active)
        end
        task.destroy
      end
    end
  end

  def self.down
    drop_table :artwork_groups
  end
end
