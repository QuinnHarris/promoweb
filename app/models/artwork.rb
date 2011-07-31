module Paperclip
  module Interpolations
    def prefix attachment, style_name
      return '' if style_name == :original
      "#{style_name}/"
    end

    def uuid attachment, style_name
      attachment.instance.customer.uuid
    end

    def fullfilename attachment, style_name
      str = "#{attachment.original_filename}"
      ext = (style = attachment.styles[style_name]) && style[:format]
      str += ".#{ext}" if ext
      str
    end
  end
end

class Artwork < ActiveRecord::Base
  has_many :tags, :class_name => 'ArtworkTag'
  belongs_to :user
  belongs_to :group, :class_name => 'ArtworkGroup'
  def customer; group.customer; end

  has_attached_file :art, :url => proc { |r| "/customer/:prefix:uuid/:fullfilename" }, :path => "#{DATA_ROOT}:url", :whiny_thumbnails => false, :styles => { :thumb => { :geometry => "160x100", :format => :png } }, :processors => [:flexThumbnail]

  after_post_process :clean_nil
  def clean_nil
    art.queued_for_write.delete(:thumb) if art.queued_for_write[:thumb].nil?
    true
  end
    
  def has_tag?(tag)
    tags.to_a.find { |t| t.name == tag }
  end

  def can_pdf?
    %w(.ps .eps .ai).include?(File.extname(art.original_filename).downcase)
  end

  def can_virtual?
    %w(.jpg).include?(File.extname(art.original_filename).downcase)
  end

  def eps?
    %w(.eps).include?(File.extname(art.original_filename).downcase)
  end

  def can_proof?(order)
    return false unless eps?

    decorations = group.decorations_for_order(order)
    return false if decorations.empty?

    decorations.find { |d| d.has_dimension? }
  end

  def filename_pdf
    "#{art.send('interpolate', ':basename')}.pdf"
  end
  
  validates_attachment_presence :art
  validates_each :art do |record, attr_name, value|
    if Artwork.find(:first, :include => :group,
                    :conditions =>
                    ["artwork_groups.customer_id = ? AND artworks.art_file_name = ?" + (record.id && " AND artworks.id != ?").to_s,
                     record.group.customer_id, value.original_filename ] + [record.id].compact)
      logger.info("NOT UNIQ")
      record.errors.add(attr_name, 'Filename not Unique')
    end
  end

end
