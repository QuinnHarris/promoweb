# -*- coding: utf-8 -*-
class EPSError < StandardError
end

class EPSInfo
  def initialize(file_name)
    @file_name = file_name
    find_declares
  end

  private
  def find_declares(count = 100)
    @declares = {}
    File.open(@file_name).each do |line|
      if /^%%(\w+):\s(.+)$/ === line
        @declares[$1] = $2
      end
      count -= 1
      return if count == 0
    end
  end

  def format_bounding(header)
    header.split(/\s+/).collect { |s| Float(s) }
  end

  public
  # llx lly urx ury
  def bounding_box
    return @bounding_box if @bounding_box
    @bounding_box = format_bounding @declares["HiResBoundingBox"] || @declares["BoundingBox"]
  end

  def width
    bounding_box[2] - bounding_box[0]
  end

  def height
    bounding_box[3] - bounding_box[1]
  end

  def left
    bounding_box[0]
  end

  def bottom
    bounding_box[1]
  end

  def page_bounding_box
    format_bounding @declares["PageBoundingBox"] || @declares["HiResBoundingBox"] ||  @declares["BoundingBox"]
  end

  def inspect
    "#{@file_name} : #{width}x#{height}"
  end
end

class RGhost::Paper
  def size
    case @paper
      when Symbol
        RGhost::Constants::Papers::STANDARD[@paper.to_s.downcase.to_sym]
      when Array
        @paper
    end
  end
end

class RGhost::Document
  attr_reader :paper
end

class EPSPlacement < EPSInfo
  @@tick_offset = 4
  @@tick_length = 18
  cattr_reader :tick_length, :tick_offset

  attr_accessor :scale

  attr_reader :diameter
  def diameter=(val)
    @width_imprint = @height_imprint = @diameter = Float(val)
  end

  %w(width height).each do |name|
    define_method "#{name}_imprint" do
      instance_variable_get("@#{name}_imprint")
    end

    define_method "#{name}_imprint=" do |val|
      val = Float(val)
      if !@scale && send(name) > val
        raise EPSError, "#{name} of #{send(name)}pt > #{val}pt (#{send(name)/72.0}in > #{val/72.0}in) for #{@file_name}"
      end
      instance_variable_set("@#{name}_imprint", val)
    end
    
    define_method "#{name}_full" do
      send("#{name}_imprint") + 2*(@@tick_offset + @@tick_length)
    end
  end

  def draw(doc, center_x, center_y)
    # Crop marks
    doc.graphic do |g|
      g.line_width 0.5
      (0..3).each do |n|
        x_dir = (n&1 == 1) ? -1 : 1
        y_dir = (n&2 == 2) ? -1 : 1
        
        g.moveto :x => center_x + x_dir*width_imprint/2, :y => center_y + y_dir*(height_imprint/2 + @@tick_offset)
        g.rlineto :x => 0, :y => y_dir*@@tick_length
        
        g.moveto :x => center_x + x_dir*(width_imprint/2 + @@tick_offset), :y => center_y + y_dir*height_imprint/2
        g.rlineto :x => x_dir*@@tick_length, :y => 0
      end
      g.stroke
    end

    # Outline
    if diameter
      doc.circle :x => center_x, :y => center_y, :radius => diameter / 2.0, :content => {:fill => false}, :border => { :color => :yellow, :width => 0.25 }
    else
      doc.graphic do |g|
          g.line_width 0.25
          g.border :color => :yellow
          g.moveto :x => center_x - width_imprint/2, :y => center_y - height_imprint/2
          g.rlineto :x => width_imprint, :y => 0
          g.rlineto :x => 0, :y => height_imprint
          g.rlineto :x => -width_imprint, :y => 0
          g.rlineto :x => 0, :y => -height_imprint
        g.stroke
      end
    end

    # Crop mark Label
    doc.moveto :x => center_x, :y => center_y - height_imprint / 2 - @@tick_offset - @@tick_length
    doc.show "#{width_imprint / 72.0} in", :with => :label_font, :align => :show_center
    
    doc.moveto :x => center_x + width_imprint / 2 + @@tick_offset + @@tick_length / 2, :y => center_y - 4
    doc.show "#{height_imprint / 72.0} in", :with => :label_font
    
    # Scale
    offset_x = -left
    offset_y = -bottom
    scale_note = nil
    s = scale ? [width_imprint/width, height_imprint/height].min : 1.0
    if !scale || (s == width_imprint/width)
      offset_y += (height_imprint - height*s)/2
      scale_note = "width"
    end
    if !scale || (s == height_imprint/height)
      offset_x += (width_imprint - width*s)/2
      scale_note = "height"
    end

    unless s == 1.0
      doc.moveto :x => center_x, :y => center_y - height_imprint / 2 - @@tick_offset - @@tick_length - 16
      doc.show "Scaled #{'%0.2f' % (s * 100)}% (by #{scale_note})", :align => :show_center
      doc.scale(s, s)
    end

    # Insert eps
    doc.image @file_name, :x => (center_x - width_imprint/2 + offset_x)/s, :y => (center_y - height_imprint/2 + offset_y)/s
  end

  def inspect
    super + " : #{width_full}x#{height_full}"
  end
end


class ImagePlacement
  def initialize(file_name)
    @file_name = file_name
    @exif = EXIRF::JPEG.new(file_name)
  end

  def width
    @exif.width
  end
  def height
    @exif.height
  end

  def draw(doc, center_x, center_y)
    
  end
end


class ElementLayout
  def initialize(hash)
    @width = hash[:width]
    @height = hash[:height]
    @columns = hash[:columns]
    @rows = hash[:rows]
    @elements = hash[:elements]
    @note = hash[:note]
  end
  attr_reader :width, :height, :columns, :rows, :elements, :note
  
  def score
    Rails.logger.info("Score: #{width} #{height} #{columns} #{rows} #{note} #{elements.inspect}")
    score = 0.0

    @row_space = []
    @col_space = []

    # Score column spacing
    (0...rows).each do |row|
      w = (0...columns).inject(0) do |sum, col|
        e = elements[row*columns + col]
        sum + (e ? e.width_full : 0.0)
      end
      Rails.logger.info("Col: #{w} #{width}")
      return nil if w > width
      score += Math.log((width - w)/(columns + 1))
      @row_space[row] = (width - w).to_f / (columns+1)
    end

    # Score row spacing
    (0...columns).each do |col|
      h = (0...rows).inject(0) do |sum, row|
        e = elements[row*columns + col]
        sum + (e ? e.height_full : 0.0)
      end
      Rails.logger.info("Row: #{h} #{height}")
      return nil if h > height
      score += Math.log((height - h)/(rows + 1))
      @col_space[col] = (height - h).to_f / (rows + 1)
    end

    Rails.logger.info("NUM: #{score}")

    return score
  end

  def draw(doc, center_x, center_y)
    left = center_x - width / 2.0
    bottom = center_y - height / 2.0

    (0...rows).each do |row|
      x = left
      (0...columns).each do |col|
        e = elements[row*columns + col]
        return unless e
        x += @row_space[row]
        x += e.width_full / 2.0

        y = bottom + @col_space[col]
        (0...(rows-row-1)).each do |r|
          y += @col_space[col]
          y += e.height_full
        end
        y += e.height_full / 2.0
        
        Rails.logger.info("X: #{x} Y: #{y}")
        e.draw(doc, x, y)

        x += e.width_full / 2.0
      end
    end
  end

  def self.best(dims, elements)
    Rails.logger.info("Dims: #{dims.inspect} #{elements.inspect}")
    layouts = []
    dims.each do |width, height, note, bias|
      (1..elements.length).each do |cols|
        l = self.new(:width => width, :height => height, :note => note,
                     :columns => cols, :rows => elements.length / cols, :elements => elements)
        s = l.score
        layouts << [s+bias, l] if s
      end
    end

    raise EPSError, "Can't fit elements: #{dims.inspect}" if layouts.empty?

    layouts.sort_by { |s, l| s }.last.last
  end
end
  

class ProofGenerate
  def initialize(elements, list)
    @header_list = list
    @margin_x = 12
    @margin_y = 72*3/4

    @paper_type = :letter
    paper_size = RGhost::Constants::Papers::STANDARD[:letter]
    Rails.logger.info("Paper: #{paper_size.inspect}")
    @header_size = 72*3/2
    @footer_size = 34
    header_footer_size = @header_size + @footer_size
    
    dims = [[paper_size[1] - 2*margin_x, paper_size[0] - 2*margin_y - footer_size - header_size(true), :landscape, 0],
            [paper_size[0] - 2*margin_x, paper_size[1] - 2*margin_y - footer_size - header_size(false), :portrait, 100.0] ]
    
    @layout = ElementLayout.best(dims, elements)
    Rails.logger.info(@layout.inspect)

    if @layout.note == :landscape
      paper_size = paper_size.reverse 
      @landscape = true
    end
    @paper_width, @paper_height = paper_size
    Rails.logger.info("XXXXXXX Widht: #{@paper_width} #{@paper_height} #{@layout.note}")
  end

  attr_reader :paper_type, :paper_width, :paper_height, :footer_size, :margin_x, :margin_y, :landscape

  def center_x
    paper_width / 2
  end

  def setup(info)
    RGhost::Config::GS[:unit] = RGhost::Units::PSUnit
    Rails.logger.info("LANDSCAPE: #{landscape} #{paper_width} #{paper_height}")
    @doc = RGhost::Document.new :paper => paper_type, :landscape => landscape
    @doc.info(info)
    @doc.define_tags do
      tag :title_font, :name => 'Helvetica-Bold', :size => 36
      tag :subtitle_font, :name => 'Times', :size => 12
      tag :bold_font, :name => 'Times-Bold', :size => 14
      tag :label_font, :name => 'Helvetica', :size => 10
      tag :action_font, :name => 'Helvetica-Bold', :size => 18, :color => :blue
    end
  end

  def header_size(land = @landscape)
    36 + (@header_list.length / (land ? 2.0 : 1).ceil) * 14 + 12
  end

  def draw_head(image = nil)
    y = paper_height - margin_y - 36
    doc.moveto :x => center_x, :y => y
    doc.show "Artwork Proof", :with => :title_font, :align => :show_center

    Rails.logger.info("Land: #{landscape}")

    start_y = y - 6
    x = margin_y*2 + 72
    @header_list.in_groups_of( (@header_list.length / (landscape ? 2.0 : 1)).ceil ).each do |sub|
      y = start_y
      sub.each do |name|
        y -= 14
        doc.moveto :x => x, :y => y
        Rails.logger.info("Name: #{name.inspect}")
        doc.show name, :with => :subtitle_font, :align => :show_left
      end
      x += 72*3.75
    end

    doc.image image, :zoom => 20, :x => margin_y, :y => y if image
  end

  def draw_foot(order)
    y = margin_y
    
    doc.moveto :x => center_x, :y => y
    doc.show "www.mountainofpromos.com  (877) 686-5646", :with => :subtitle_font, :align => :show_center
    y += 14

    doc.moveto :x => center_x, :y => y
    doc.show "Mountain Xpress Promotions, LLC", :with => :bold_font, :align => :show_center

    # Links
    url_prefix = "http://www.mountainofpromos.com/orders/#{order.id}/acknowledge_artwork?auth=#{order.customer.uuid}&"
    doc.text_link "Accept", :url => url_prefix + "accept=true", :color => :blue, :x => center_x - 200, :y => margin_y + 10, :tag => :action_font
    doc.text_link "Reject", :url => url_prefix + "reject=true", :color => :blue, :x => center_x + 146, :y => margin_y + 10, :tag => :action_font

    doc.border :color => :black
  end

  def draw(dst_path)
    @layout.draw(@doc, center_x, (footer_size + (paper_height - header_size)) / 2)

    @doc.render :pdf, :filename => dst_path
  end
  attr_reader :doc

  def draw_header
    
  end
end


class Admin::ArtworkController < Admin::OrdersController
  def mark
    Artwork.transaction do
      artwork = Artwork.find(params[:id])
      raise "Art doesn't belong to customer" if artwork.group.customer_id != @order.customer_id

      tag = artwork.tags.find_by_name(params[:tag])
      raise "Already marked" if (params[:state] != "true") == tag.nil?

      if tag
        tag.destroy
      else
        artwork.tags.create(:name => params[:tag])
      end
    end

    redirect_to :back
  end

  def drop_set
    OrderItemDecoration.transaction do
      group = params['artwork-group'].empty? ? nil : ArtworkGroup.find(params['artwork-group'])
      if params[:decoration]
        object = OrderItemDecoration.find(params[:decoration])
        raise "Customer Mismatch" if group && group.customer_id != object.order_item.order.customer_id
        object.artwork_group = group
        object.save!
      elsif params[:artwork]
        object = Artwork.find(params[:artwork])
        raise "Can't change customer" unless object.group.customer_id == group.customer_id
        object.group = group
        object.save!
      end
    end
    render :inline => ''
  end
 
  def group_new
    ArtworkGroup.transaction do
      @order.customer.artwork_groups.create(:name => 'New')
    end
    redirect_to :back
  end

  def group_destroy
    ArtworkGroup.transaction do
      group = ArtworkGroup.find(params[:id])
      raise "Inconsistent customer" unless group.customer_id == @order.customer_id
      raise "Not empty" unless group.artworks.empty? and group.order_item_decorations.empty?
      group.destroy
    end
    redirect_to :back
  end

  def make_proof
    if params[:decoration_id]
      decoration = OrderItemDecoration.find(params[:decoration_id], :include => :artwork_group)
      group = decoration.artwork_group
      artworks = group.pdf_artworks
    elsif params[:artwork_id]
      artwork = Artwork.find(params[:artwork_id])
      artworks = [artwork]
      group = artwork.group
      decoration = group.order_item_decorations.first
    else
      raise "Unknown Source"
    end

    raise "No Artworks" if artworks.empty?

    placements = artworks.collect do |artwork|
      eps = EPSPlacement.new(artwork.art.path)
      eps.scale = params[:scale]
      logger.info("Width: #{eps.width} #{eps.height} #{decoration.diameter} #{decoration.width} #{decoration.height}")
      if diameter = decoration.diameter
        eps.diameter = diameter * 72
      else
        eps.width_imprint = decoration.width * 72
        eps.height_imprint = decoration.height * 72
      end
      eps
    end

    # Header
    product_name = decoration.order_item.product.name.gsub('”','"').gsub('’',"'")

    company_name = group.customer.company_name.strip.empty? ? group.customer.person_name : group.customer.company_name

    decoration_location = decoration.decoration && (decoration.decoration.location.blank? ? nil : decoration.decoration.location.gsub(/(\W|[^[:print:]])+/, ' '))
    info_list = ["Customer: #{company_name}",
     "Product: #{product_name}",
     decoration_location && "Location: #{decoration_location}",
     @order.user && "Rep: #{@order.user.name} (#{@order.user.email})"
    ].compact

    props = {}
    imprint = []
    names = decoration.order_item.product.property_group_names
    decoration.order_item.order_item_variants.each do |oiv|
      next if oiv.quantity == 0

      names.each do |name|
        val = oiv.variant && (p = oiv.variant.properties.to_a.find { |p| p.name == name })
        props[name] = (props[name] || []) + [val ? val.value : 'Not Specified']
      end
      imprint << oiv.imprint_colors
    end

    props.each do |key, list|
      info_list << "#{key.capitalize}: #{list.join(', ')}"
    end
    info_list << "Imprint: #{imprint.join(', ')}" unless imprint.empty?

    if decoration.order_item.product.product_images.empty?
      product_image = decoration.order_item.product.image_path_absolute('main', 'jpg')
    else
      product_image = decoration.order_item.active_images.first.image.path(:medium)
    end

    proof = nil
    begin
      proof = ProofGenerate.new(placements, info_list)
    rescue EPSError => e
      @error = e
      return
    end
    proof.setup(:Title => 'Artwork Proof',
                :Author => @order.user && @order.user.name,
                :Subject => "#{product_name} on #{decoration_location}",
                :Producer => "Mountain Xpress Proof Creator using RGhost v#{RGhost::VERSION::STRING}")

    proof.draw_head(product_image)
    proof.draw_foot(@order)

    dst_path = "/tmp/rghost-#{Process.pid}.pdf"
    proof.draw(dst_path)

    dst_name = params[:artwork_id] ? artwork.filename_pdf : decoration.pdf_filename
    art_file = File.open(dst_path)
    eval "def art_file.original_filename; #{dst_name.inspect}; end"

    # Generate Artwork
    Artwork.transaction do
      proof_art = Artwork.find(:first, :include => :group, :conditions => ["artwork_groups.customer_id = ? AND artworks.art_file_name = ?", group.customer_id, dst_name])
      raise "File already exists" if proof_art

      proof_art = Artwork.create({ :group => group,
                                   :user => @user, :host => request.remote_ip,
                                   :customer_notes => "Proof generated from #{artworks.collect { |a| a.art.original_filename }.join(', ')}",
                                   :art => art_file })
      proof_art.tags.create(:name => 'proof')

      if params[:artwork_id] && !artwork.tags.find_by_name('supplier')
        artwork.tags.create(:name => 'supplier')
      end
    end
   
    redirect_to artwork_order_path(@order)
  end

  def inkscape
    @oid = OrderItemDecoration.find(params[:id])
    if standard_colors = @oid.order_item.product.supplier.standard_colors
      @colors = standard_colors.collect do |color| 
        Pantone::Color.find(color)
      end
    end
    render :layout=>false, :content_type => 'application/inkscape'
  end
end
