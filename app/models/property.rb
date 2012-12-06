# -*- coding: utf-8 -*-
module Paperclip
  module Interpolations
    def name_value attachment, style_name
      "#{attachment.instance.name}_#{attachment.instance.value}"
    end
  end
end

class Float
  def to_perty
    whole = Integer(self)
    decimal = self - whole
    tail = case decimal
           when 0;       ''
           when 0.125;   '⅛'
           when 0.25;    '¼'
           when 0.375;   '⅜'
           when 0.5;     '½'
           when 0.625;   '⅝'
           when 0.75;    '¾'
           when 0.875;   '⅞'
           end
    unless tail
      if (decimal - 1.0/3.0).abs < 1e-10
        tail = '⅓'
      elsif (decimal - 2.0/3.0).abs < 1e-10
        tail = '⅔'
      end
    end
    unless tail
      nds = decimal * 32
      if nds.round == nds
        div = nds.to_i.gcd(32)
        tail = " #{nds.to_i/div}/#{32/div}"
      end
    end
    return self.to_s unless tail
    (whole == 0 ? '' : whole.to_s) + tail
  end
end

class Integer
  def to_perty; to_s; end
end


class Property < ActiveRecord::Base
  has_and_belongs_to_many :variants
  
  # name
#  serialize :value
  
  def translate
    hash = {
      'dimension' => Proc.new do |v| 
        begin
          v.split(',').collect do |s|
            key, value = s.split(':')
            key = key[0..0].upcase
            value = Float(value)
            if value > 23.0
              if value % 36 == 0
                next "#{value / 36} yards #{key}"
              else
                next "#{Integer(value / 12)}' #{(value % 12).to_perty}\" #{key}"
              end
            end
            "#{value.to_perty}\"#{key}"
          end.join(' x ')
        rescue
          v
        end
      end,
      'swatch' => Proc.new do |v|
        image.url
      end
    }
    
    val = hash[name]
    if val
      val.call(value)
    else
      value
    end  
  end
  
  def self.is_image?(name)
    name == 'swatch'
  end
  
  def is_image?
     name == 'swatch'
  end
  
  def is_option?
    name != 'swatch'
  end

  has_attached_file :image, :url => "/data/property/:name_value.:extension", :path => "#{DATA_ROOT}:url", :styles => {
    :original => { :geometry => '72x36>', :format => 'png' } }, :default_style => :original, :convert_options => { :all => "-strip" }

  def image_file_name; "x.png"; end
  def image_file_name=(set); end;
  
  
  def self.get(name, value)
    prop = Property.find_by_name_and_value(name, value)
    return prop if prop
    Property.create({:name=>name,:value=>value})
  end  
end
