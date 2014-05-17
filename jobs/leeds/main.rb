require '../generic_import'
require './import'

class LeedsXLS < PolyXLS
  def initialize
    @src_urls = ['http://media.leedsworld.com/msfiles/downloads/WebDecorationMethodByItem.xls']
    # USDcatalog
    # USDMemorycatalog 
    @src_urls += %w(USDcatalog).collect do |name|
      "http://media.leedsworld.com/ms/?/excel/#{name}/EN"
    end
    @image_url = 'images.leedsworld.com'
    @common_cols_extra = %w(ApparelItem)
    @unique_cols_extra = %w(ItemLength ItemWidth ItemHeight ProductSKU ApparelSize ApparelGender Color)
    super "Leeds"
  end

  def process_variants(pd, common, unique)
    images = @image_list[pd.supplier_num] || []

    pd.variants = unique.collect do |src|
      properties = {}

      properties['dimension'] =
        %w(length width height).each_with_object({}) do |name, hash|
        num = src["Item#{name.capitalize}"].to_f
        hash[name] = num unless num == 0.0
      end
      
      if common['ApparelItem'] == 'Yes'
        properties['size'] = src['ApparelSize']
        properties['gender'] = src['ApparelGender']
      end
      
      # If Leeds
      color = properties['color'] = src['Color']
      var_images = images.find_all { |node, var| src['ProductSKU'].include?(pd.supplier_num + var) }
      images -= var_images
      
      VariantDesc.new(:supplier_num => src['ProductSKU'],
                      :properties => properties,
                      :images => var_images.map(&:first))
    end

    pd.images = images.map(&:first)
  end
end

import = LeedsXLS.new
import.run_all
#import.run_parse_cache
#import.purge_image_cache(WebFetch.cache_dir + '/images.leedsworld.com/')
