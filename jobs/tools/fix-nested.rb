require File.dirname(__FILE__) + '/../../config/environment'

def add_sub(root, left)
  puts "#{root.name}: (#{left})"
  right = left + 1
  (Category.find_all_by_parent_id(root.id) - [$root]).each do |child|
    right = add_sub(child, right) + 1
  end
  puts "#{left} - #{right}"
#  root.attributes['lft'] = left
#  root.attributes['rgt'] = right
  Category.connection.execute("UPDATE categories SET lft = #{left}, rgt = #{right} WHERE id = #{root.id}")
#  root.save!
  return right
end

Category.transaction do
  Category.connection.execute("UPDATE categories SET lft = 0, rgt = 0")
  $root = Category.find_by_name("root")
  
  # Initialize root
#  root.add_child(root)
  
  add_sub($root, 1)
end

