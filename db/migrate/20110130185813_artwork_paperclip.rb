class ArtworkPaperclip < ActiveRecord::Migration
  def self.up
    rename_column :artworks, :file, :art_file_name
    add_column :artworks, :art_content_type, :string
    add_column :artworks, :art_file_size, :integer

    Artwork.find(:all).each do |artwork|
      artwork.art.reprocess!
    end
  end

  def self.down
    remove_column :artworks, :art_file_size
    remove_column :artworks, :art_content_type
    rename_column :artworks, :art_file_name, :file
  end
end
