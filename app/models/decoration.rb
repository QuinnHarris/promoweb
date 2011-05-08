class Decoration < ActiveRecord::Base
  belongs_to :product
  belongs_to :technique, :class_name => 'DecorationTechnique', :foreign_key => 'technique_id'
  
  has_many :order_item_decorations
  # location
  # 
  def dimension_s
    if diameter
      "#{diameter} dia"
    elsif width
      "#{width}W x #{height}H"
    end
  end

  def display
    "#{location} (#{dimension_s})"
  end

  def blank?
    location.blank? && width.blank? && height.blank? && diameter.blank?
  end
end
