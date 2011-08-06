module Magick
  class Image
    def box_vignette(border, mult)
      y_curve = border*mult
      x_curve = y_curve*columns/rows
    
      oval = Image.new(columns, rows) {self.background_color = 'white'}
      gc = Draw.new
      gc.stroke('black')
      gc.fill('black')
      [[border+x_curve, border+y_curve],
       [columns-(border+x_curve), border+y_curve],
       [border+x_curve, rows-(border+y_curve)],
       [columns-(border+x_curve), rows-(border+y_curve)]].each do |x, y|
        gc.ellipse(x, y,
                   x_curve, y_curve, 0, 360)
        end
    
      gc.rectangle(border+x_curve,border, columns-(border+x_curve),rows-border)
      gc.rectangle(border,border+y_curve, columns-border,rows-(border+y_curve))
    
      gc.draw(oval)
    
      oval = oval.blur_image(0, border/2)
    
      oval.matte = false
    
      composite(oval, CenterGravity, ScreenCompositeOp)
    end
  end
end

# RecordImages
module RecordImages
  def self.append_features(base)
    super
    base.extend(ClassMethods)
  end

  module ClassMethods
    def record_images(options)
      write_inheritable_attribute(:image_options, options)
      class_inheritable_reader :image_options
      
      class_eval <<-EOV
        include RecordImages::InstanceMethods
      EOV
    end
  end
  
  module InstanceMethods
    def image_file_name(name, ext, num = 1)
#      save! if new_record?  # Make sure we have an id
      "#{id}_#{name}_#{num}.#{ext}"
    end
    
    def image_pre_path
      "/data/#{ActiveSupport::Inflector.underscore(self.class.name)}/#{id}"
    end
  
    def image_path_relative(name, num = 1)
      options = get_image_options(name)
      File.join(image_pre_path, image_file_name(name, options[:ext], num))
    end
    
    def image_path_absolute(name, ext, num = 1)
#      pre = File.join(DATA_ROOT, "public")
      pre = File.join(DATA_ROOT, image_pre_path)
      FileUtils.mkdir_p(pre)
      File.join(pre, image_file_name(name, ext, num))
    end
  
    def get_image_options(name)
      opt = image_options[name]
      raise "Unknown Image Option" unless opt
      opt
    end
    
    def image_exists?(name, num = 1)
#      return nil if new_record?
      options = get_image_options(name)
      begin
        return File.stat(image_path_absolute(name, options[:ext], num)).file?
      rescue Errno::ENOENT
        return nil
      end        
    end
    
    def image_import(src, name, num = 1)
      return nil if image_exists?(name, num)
      
      options = get_image_options(name)
      dst = image_path_absolute(name, options[:ext], num)
      
      if File.basename(src).split('.').last == options[:ext] and !options[:size]
        FileUtils.cp(src, dst)
        return true
      end
      
      img = Magick::ImageList.new(src).first
      if options[:size]
        img = img.change_geometry(options[:size]) do |c, r, i|
          i.resize(c, r)
        end
      end
      img.write(dst)
      
      true
    end
    
    def image_copy(src, name, num = 1)
      return nil if image_exists?(name, num)
      base = File.basename(src)
      ext = base.split('.').last
#      raise "Must match specified extension #{ext} != #{get_image_options(name)[:ext]}" unless ext.downcase == get_image_options(name)[:ext]
      dst = image_path_absolute(name, get_image_options(name)[:ext], num)
      FileUtils.cp(src, dst)
      dst
    end
    
    def image_convert(src, name, num = 1)
      return nil if image_exists?(name, num)
      base = File.basename(src)
      ext = base.split('.').last
      img = Magick::ImageList.new(src).first
      dst = image_path_absolute(name, get_image_options(name)[:ext], num)
      puts "Convert: #{src} => #{dst}"
      img.write(dst)
#      dst
      img      
    end
    
    def image_transform(src, name, num = 1)
      return nil if image_exists?(name, num)
      options = get_image_options(name)
      img = src.is_a?(Magick::Image) ? src : Magick::ImageList.new(src).first
      img = img.change_geometry(options[:size]) do |c, r, i|
        res = i.resize(c, r)
        res = yield res if block_given?
        res
      end
      dst = image_path_absolute(name, options[:ext],num)
      img.write(dst) { self.quality = options[:quality] if options[:quality] }
      dst
    end
  end
end
