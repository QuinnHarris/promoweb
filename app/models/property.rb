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
            value + '"' + key[0..0].upcase
          end.join(' x ')
        rescue
          v
        end
      end,
      'swatch' => Proc.new do |v|
        image_path_relative('medium')
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
  
  record_images({ 'medium' => { :ext => 'gif' },
                  'small' => { :ext => 'gif' } })
  
  def self.get(name, value)
    prop = Property.find_by_name_and_value(name, value)
    return prop if prop
    Property.create({:name=>name,:value=>value})
  end  
end
