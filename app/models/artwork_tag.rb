class ArtworkTag < ActiveRecord::Base
  belongs_to :artwork
  
  OrderTask
  @@tag_mapping = {
    'proof' => [ArtPrepairedOrderTask], #, 'supplier'],
    'supplier' => [ArtSentItemTask], #, 'proof'],
    'customer' => [nil]
  }

  def self.tags_availible(tags)
    @@tag_mapping.collect do |name, list|
      [name, (list[1..-1] & tags).empty? && list.first]
    end
  end
end
