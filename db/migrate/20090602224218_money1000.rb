# Kludge to preload Model classes
$rails_rake_task = false
config = Rails::Configuration.new
config.cache_classes = true
Rails::Initializer.new(config).load_application_classes
$rails_rake_task = true


class Money1000 < ActiveRecord::Migration
  def self.modify_fields(list, tail)
    list.collect { |e| "#{e} = #{e} #{tail}" }.join(', ')
  end

  def self.money_objects
    ret = {}
    ActiveRecord::Base.send(:subclasses).each do |klass|
      next unless klass.superclass == ActiveRecord::Base
      next unless reflection = klass.read_inheritable_attribute(:reflections)
      composed_of = reflection.find_all { |k, v| v.macro == :composed_of }.collect { |k, v| v.options }
      fields = []
      composed_of.each do |options|
        mapping     = options[:mapping]
        mapping     = [ mapping ] unless mapping.first.is_a?(Array)
        if %w(Money PricePair).include?(options[:class_name])
          fields += mapping.collect do|field, attr| 
            raise "#{klass}: #{field} should be units" if options[:class_name] == 'Money' and attr != 'units'
            field
          end
        end
      end
      ret[klass] = fields.uniq unless fields.empty?
    end
    ret
  end

  def self.update_attr!(hash, &block)
    hash.each do |k, v|
      if v.is_a?(Hash)
        update_attr!(v, block)
      elsif v.is_a?(Array)
        v.each { |h| update_attr!(h, &block) }
      elsif /_price$/ === k.to_s
        hash[k] = yield v
      end
    end
  end

  def self.up
    InvoiceOrderItem.find(:all).each do |item|
      update_attr!(item.data) { |v| v && (v * 10) }
      item.save!
    end

    money_objects.each do |klass, fields|
      puts "#{klass}: #{fields.inspect}"
      klass.update_all(modify_fields(fields, "* 10"))
    end
  end

  def self.down
    money_objects.each do |klass, fields|
      puts "#{klass}: #{fields.inspect}" unless fields.empty?
      klass.update_all(modify_fields(fields, "/ 10"))
    end

    InvoiceOrderItem.find(:all).each do |item|
      update_attr!(item.data) { |v| v && (v / 10) }
      item.save!
    end
  end
end
