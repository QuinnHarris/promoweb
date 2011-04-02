class ArtworkTag < ActiveRecord::Base
  belongs_to :artwork
  
  OrderTask
  @@tag_mapping = {
    'proof' => ArtPrepairedOrderTask,
    'supplier' => ArtSentItemTask,
    'customer' => nil
  }
  cattr_accessor :tag_mapping
end
