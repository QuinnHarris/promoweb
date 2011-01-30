class Artwork < ActiveRecord::Base
  has_many :tags, :class_name => 'ArtworkTag'
  belongs_to :user
  belongs_to :group, :class_name => 'ArtworkGroup'
  def customer; group.customer; end

  image_column :file, :root_dir => DATA_ROOT, :web_root => '', :store_dir => proc { |r| "customer/#{r.customer.uuid}" }, :get_content_type_from_file_exec => true, :manipulator => nil
#:versions => { :thumb => '160x120' },
    
  def has_tag?(tag)
    tags.to_a.find { |t| t.name == tag }
  end

  def can_pdf?
    %w(ps eps ai).include?(file.extension)
  end

  def can_proof?(order)
    return false unless %w(eps).include?(file.extension)

    decorations = group.decorations_for_order(order)
    return false if decorations.empty?

    decorations.find { |d| d.has_dimension? }
  end

  def filename_pdf
    "#{file.basename}.pdf"
  end
  
#  validates_presence_of :file
  validates_each :file do |record, attr_name, value|
    if Artwork.find(:first, :include => :group,
                    :conditions => ["artwork_groups.customer_id = ? AND artworks.file = ? AND artworks.id != ?",
                                    record.group.customer_id, value.filename, record.id ])
      record.errors.add(attr_name, 'Filename not Unique')
    end
  end
#  validates_filesize_of :file, :in => 0..20.megabytes
end
