class ArtworkGroup < ActiveRecord::Base
  belongs_to :customer
  has_many :artworks, :foreign_key => :group_id, :order => 'id DESC'
  has_many :order_item_decorations

  def decorations_for_order(order)
    order_item_decorations.find(:all, :include => :order_item,
                                :conditions => { 'order_items.order_id' => order.id })
  end

  def pdf_artworks
    artworks.to_a.find_all { |a| a.can_pdf? && a.has_tag?('supplier') }
  end

  def pdf_filename
    "#{name} Proof.pdf"
  end

  def pdf_exists?
    artworks.to_a.find { |a| a.art.original_filename == pdf_filename }
  end
end
