require File.dirname(__FILE__) + '/../config/environment'

PageAccess.find(:all, :conditions => 
                { :controller => 'products',
                  :action => 'main',
                  :action_id => nil }).each do |access|

  puts "A ID: #{access.action_id.inspect}  Param: #{access[:params].inspect}  #{access.id}"
  if access[:params]['id']
    id_prefix = access[:params]['id'].split(/-|\&|\?/).first
    id_num = id_prefix.to_i
    if id_num.to_s == id_prefix
      access[:params].delete('id') if id_num.to_s == access[:params]['id'].to_s
      access.action_id = id_num
      access.save!
    end
  end
  puts "B ID: #{access.action_id.inspect}  Param: #{access[:params].inspect}  #{access.created_at}"

end
