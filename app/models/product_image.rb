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
    :medium => { :geometry => '400x320>', :format => :jpg },
    :thumb => { :geometry => '120x120>', :format => :jpg },
    :large => { :geometry => '', :format => :jpg },
  }, :convert_options => {
    :all => "-quality 85 -strip",
  }
  validates_attachment_content_type :image, :content_type => ["image/jpg", "image/jpeg"]

  # Always a JPEG
  def image_content_type
    'image/jpeg'
  end
  
  def image_file_name; 'x.jpg'; end
  def image_file_name=(set); end;
end
