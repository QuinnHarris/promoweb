class PhrasePermute
private
  def cross(a, b)
    a.collect { |x| b.collect { |y| [x, y].compact.join(' ') } }.flatten
  end
  
  def combine(a, b)
    cross(a, b) + a + b
  end

public
  def initialize(obj)
    @adjective, @noun, @include, @exclude =
    %w(Adjective Noun Include Exclude).collect do |type|
      obj.keywords.find(:all, :conditions => "name = '#{type}'").collect do |keyword|
        keyword.phrase
      end
    end
  end
  
  attr_reader :adjective, :noun, :include, :exclude
  
  # imprinted promotional
  
#  @@prefix_pre = ['custom', 'trade show', 'handout']
#  @@prefix = %w(imprinted printed promotional embroidered logo)
#  @@prefix_post = %w(wholesale discounted)
  
  def general_prefix
#    combine(@@prefix_pre, @@prefix) +
#      cross(@@prefix_pre, @@prefix_post)
    
    combine(%w(custom trade\ show handout),
            combine(%w(imprinted printed embroidered logo),
                    %w(promotional)))
  end
  
  def specific_prefix
    cross(general_prefix, @adjective + [nil])
  end
  
  def nouns
#    @noun.collect { |n| [n, n+'s'] }.flatten
    @noun
  end
  
  def terms
    cross(specific_prefix, nouns)
  end

  def complete
    (terms + @include) - @exclude
  end
end

class Keyword < ActiveRecord::Base
  has_and_belongs_to_many :categories
  
  def self.get(phrase)
    keyword = find_by_phrase(phrase)
    keyword = create({:phrase => phrase}) unless keyword
    keyword
  end
end
