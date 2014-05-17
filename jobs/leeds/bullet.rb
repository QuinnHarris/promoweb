require '../generic_import'
require './import'

class BulletXLS < PolyXLS
  def initialize
    @src_urls = ['http://www.bulletline.com/services/downloads/excel/WebDecorationMethodByItem.xls']
    @src_urls << 'http://www.bulletline.com/services/downloads/excel/Catalog.xls'
    @image_url = 'images.bulletline.com'
    @common_cols_extra = %w(Color ItemLength ItemWidth ItemHeight)
    super "Bullet Line", :prune_colors => true
  end

  # Bullet uses a color list, Leeds lists a color per line
  def process_variants(pd, common, unique)
    pd.properties['dimension'] =
      %w(length width height).each_with_object({}) do |name, hash|
      num = common["Item#{name.capitalize}"].to_f
      hash[name] = num unless num == 0.0
    end

    colors = common['Color'].to_s.split(/\s*(?:(?:\,|(?:\sor\s)|(?:\sand\s)|\&)\s*)+/).uniq
    colors = [''] if colors.empty?

    color_image_map, color_num_map = match_colors(colors, :prune_colors => @options[:prune_colors])
    #puts "ColorMap: #{pd.supplier_num} #{color_image_map.inspect} #{color_num_map.inspect}"
    pd.images = color_image_map[nil] || []
    
    postfixes = Set.new
    pd.variants = colors.collect do |color|
      postfix = color_num_map[color] #[@@color_map[color.downcase]].flatten.first
      unless postfix
        postfix = @@color_map[color.downcase]
        postfix = color.split(/ |\//).collect { |c| [@@color_map[c.downcase]].flatten.first }.join unless postfix
        warning 'No Postfix', color
      end
      
      # Prevend duplicate postfix
      postfix += 'X' while postfixes.include?(postfix)
      postfixes << postfix
      
      VariantDesc.new(:supplier_num => "#{@supplier_num}#{postfix}",
                      :properties => {
                        'color' => color.strip.capitalize,
                      },
                      :images => color_image_map[color] || [])
    end # pd.variants
  end
end


import = BulletXLS.new
import.run_all
