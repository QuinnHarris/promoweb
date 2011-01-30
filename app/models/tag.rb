class Tag < ActiveRecord::Base
  belongs_to :product

  @@names = Tag.find_by_sql("SELECT DISTINCT name FROM tags").collect { |r| r.name }.uniq
  cattr_reader :names
end
