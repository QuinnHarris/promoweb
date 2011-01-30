class ArtworkUser < ActiveRecord::Migration
  def self.up
    add_column :artworks, :user_id, :integer
    add_column :artworks, :host, :string

    OrderTask
    ArtReceivedOrderTask.find(:all, :conditions => 'NOT NULLVALUE(data)').each do |task|
      if task.data[:id] and artwork = Artwork.find_by_id(task.data[:id])
        artwork.user_id = task.user_id
        artwork.host = task.host
        artwork.save!
      end
    end
  end

  def self.down
    remove_column :artworks, :user_id
    remove_column :artworks, :host
  end
end
