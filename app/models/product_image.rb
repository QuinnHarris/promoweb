module Paperclip
  module Interpolations
    def product_id attachment, style_name
      attachment.instance.product_id
    end
  end
end

class ProductImage < ActiveRecord::Base
  has_and_belongs_to_many :variants
  belongs_to :product

  has_attached_file :image, :url => "/data/product/:product_id/:id_:style.:extension", :default_style => :large, :path => "#{DATA_ROOT}:url", :styles => {
    :medium => '400x320>',
    :thumb => '120x120>',
  }, :convert_options => {
    :all => "-quality 85",
  }
  
  def image_file_name; 'x.jpg'; end
  def image_file_name=(set); end;

end
