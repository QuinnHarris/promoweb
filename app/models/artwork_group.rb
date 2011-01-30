class ArtworkGroup < ActiveRecord::Base
  belongs_to :customer
  has_many :artworks, :foreign_key => :group_id, :order => 'id DESC'
  has_many :order_item_decorations

  def decorations_for_order(order)
    order_item_decorations.find(:all, :include => :order_item,
                                :conditions => { 'order_items.order_id' => order.id })
  end
end
