class DecorationTechnique < ActiveRecord::Base
  acts_as_tree :order => 'name'
  
  has_many :decorations, :foreign_key => 'technique_id'
  has_many :price_groups, :class_name => "DecorationPriceGroup", :foreign_key => 'technique_id'
  
  @@order = ['Screen Print', 'Image Bonding', 'Four Color', 'Pad Print', 'Laser Engrave', 'Embroidery', 'Deboss', 'Stamp', 'Dome', 'Patch', 'LogoMagic', 'Photo Transfer', 'Personalization', 'None']
  
  def <=>(r)
    (@@order.index(name) || @@order.length) <=> (@@order.index(r.name) || @@order.length)
  end
  
  # name
end
