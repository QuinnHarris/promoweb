class ArtworkTag < ActiveRecord::Base
  belongs_to :artwork
  
  OrderTask
  @@tag_mapping = {
    'proof' => ArtPrepairedOrderTask,
    'supplier' => ArtSentItemTask,
    'customer' => nil
  }

  def self.tag_mapping(artwork = nil)
    return @@tag_mapping unless artwork

    if artwork.can_virtual?
      return @@tag_mapping.merge('virtual' => ArtPrepairedOrderTask)
    end
    @@tag_mapping
  end
end
