class DecorationTechnique < ActiveRecord::Base
  acts_as_tree :order => 'name'
  
  has_many :decorations, :foreign_key => 'technique_id'
  has_many :price_groups, :class_name => "DecorationPriceGroup", :foreign_key => 'technique_id'
  
  @@order = ['Screen Print', 'Image Bonding', 'Four Color', 'Pad Print', 'Laser Engrave', 'Embroidery', 'Deboss', 'Stamp', 'Dome', 'Patch', 'LogoMagic', 'Photo Transfer', 'Personalization', 'None']
  
  def <=>(r)
    if parent_id == r.parent_id
      l_name = name
      r_name = r.name
    else
      l_name = parent ? parent.name : name
      r_name = r.parent ? r.parent.name : r.name
    end
    (@@order.index(l_name) || @@order.length) <=> (@@order.index(r_name) || @@order.length)
  end
  
  # name
  def friendly_name
    parent ? parent.name : name
  end
end
