#require File.dirname(__FILE__) + '/../config/environment'

require 'adwords4r'
require 'pp'
#require 'delegate'
#require 'utils'
#

#class Array
#  def intersection(arr2)
#    self_sorted = self.sort
#    target_sorted = arr2.sort
#    intersection= []
#    jstart=0
#    for i in (0..self_sorted.length-1)
#      for j in (jstart..target_sorted.length-1)
#        if self_sorted[i] == target_sorted[j]
#          jstart = j+1
#          intersection[intersection.length] = self_sorted[i]
#          break
#        end
#      end
#    end
#    return intersection
#  end
#end

#puts "result = #{adwords.getFreeUsageQuotaThisMonth().getFreeUsageQuotaThisMonthReturn}"

AdWords::API.new

module AdWords
  module CriterionService 
    class Keyword
      include Comparable
      def <=>(right)
        %w(text type).each do |prop|
          l = send(prop)
          r = right.send(prop)
          #        puts "Compare: #{prop} #{l.inspect} <=> #{r.inspect}"
          next if l == r
          return -1 if l.nil?
          return 1 if r.nil?
          res = (l <=> r)
          return res unless res == 0
        end
        return 0
      end
    end
  end

  module AdService
    class TextAd
      include Comparable
      def <=>(right)
        %w(headline description1 description2 destinationUrl displayUrl).each do |prop|
          l = send(prop)
          r = right.send(prop)
#          puts "Compare: #{prop} #{l.inspect} <=> #{r.inspect}"
          next if l == r
          return -1 if l.nil?
          return 1 if r.nil?
          res = (l <=> r)
          return res unless res == 0
        end
        return 0
      end     
    end
  end
end

module MyWords
#  AdWords::API.new
  module ListModule
    def self.append_features(base)
      super
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      def setup_list(func_name, child_class)
        define_method(:initialize) do |api, parent, parent_new|
          @api, @parent = api, parent
          @child_class = child_class
          @base_name = "/home/quinn/promoweb/jobs/adwords/cache/#{func_name}"
          FileUtils.mkdir_p(@base_name)
          @file_name = "#{@base_name}/#{@parent ? @parent.name.gsub('/','\92') : 'root'}"
          if parent_new
            puts "Parent New: #{func_name}"
            @list = []
            return
          end

          begin
            @list = File.open(@file_name) { |f| Marshal.load(f) }
          rescue
            # Kludge for singleton error on Criterion
            puts "Calling: #{func_name.inspect}(#{@parent.param.inspect})"
            @list = process_return(@api.send(func_name, @parent.param))
            write_cache
          end
        end
      end
    end
    
    attr_reader :api, :parent, :file_name
    
    def write_cache
      File.open(@file_name,"w+") { |f| Marshal.dump(@list, f) }
    end
    
    def process_return(list)
      list
    end
       
    def list
      @list.dup.freeze
    end
    
    def stats(start, stop)
      @api.send("get#{@child_class}Stats", @id, @list.collect { |e| e.id }, start, stop, false)
    end
    
    def create
      @child_class.new(@api, self)
    end

    def update(dst)
      elem = @list.find { |l| l.id == dst.id }
      raise "Couldn't find: #{dst.inspect}" unless elem
      res = process_return(apply_update([elem]))
      @list[@list.index(elem)] = res
      write_cache
      res.first
    end
    
    def add(dst)
      res = process_return(apply_add([dst]))
      @list += res
      write_cache
      res.first
    end
      
    def update_list(dst)
      common = []
      update = []
      add = []
      delete = []
      
      dst = dst.sort
      src = @list.sort
      
      until dst.empty? and src.empty?
        if dst.first == src.first
          dst.shift
          common << src.shift
#        elsif update_compare(src.first, dst.first)
#          update << update_apply(src.shift, dst.shift)
        elsif !dst.empty? and (src.empty? or dst.first < src.first)
          add << dst.shift
        else
          delete << src.shift
        end
      end

      return if add.empty? and delete.empty? and add.empty?

      puts "common: #{common.size},  add: #{add.size},  update: #{update.size}, delete: #{delete.size}"

#      puts "Comon: #{common.inspect}"
#      puts "Add: #{add.inspect}"
#      puts "Delete: #{delete.inspect}"
      
      update = process_return(apply_update(update)) unless update.empty?
      delete = apply_delete(delete) unless delete.empty?
      add = process_return(apply_add(add)) unless add.empty?
      
      @list = (common + update + add) - delete
#      puts "Final: #{@list.inspect}"
      write_cache
    end
    
    def empty?
      @list.empty?
    end
    
    def find(&block)
      res = @list.find(&block)
      return nil unless res
      @child_class.new(@api, self, res)
    end
    
    def find_all(&block)
      res = @list.find_all(&block)
      return nil unless res
      res.collect { |e| @child_class.new(@api, self, e) }
    end

    def method_missing(method_id, *arguments)
      if match = /find_(all_by|by)_([_a-zA-Z]\w*)/.match(method_id.to_s)
        method = match.captures.first == 'all_by' ? :find_all : :find
        name = match.captures.last
        
        super unless @list.first.methods.index(name)
        
        send(method) { |i| i.send(name) == arguments.first }
      else
        super
      end
    end
  end
  
  module ElementModule  
    def self.append_features(base)
      super
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      def setup_element(get_list = nil)
        @list_methods = get_list

        get_list.each do |kls|
          define_method("#{kls.to_s.downcase}s") do
            var = "@target_#{kls}"
            return instance_variable_get(var) if instance_variables.index(var)
            value = Object.const_get("MyWords").const_get("#{kls}List").new(api, self, @new)
            instance_variable_set(var, value)
          end
          
          define_method("#{kls.to_s.downcase}s=") do |value|
            target = send("#{kls.to_s.downcase}s")
            target.update_list(value)
          end        
        end if get_list
      end
    end
    
    def initialize(api, parent, object = nil)
      @api, @parent = api, parent
      copy_instance_variables_from(object) if object
      @new = !object
#      unless object
#        self.class.instance_variable_get("@list_methods").each do |kls|
#          instance_variable_set("@target_#{kls}", [])
#        end
#      end
    end

    attr_reader :api

    def save
      res = if @id
        @parent.update(self)
      else
        @parent.add(self)
      end
      copy_instance_variables_from(res)
    end

    def param
      @id
    end
  end
  
  class API #< AdWords::API
    include ElementModule
    setup_element [:Campaign]

    def initialize(api = AdWords::API.new)
      @api = api
      super api, nil, true
    end

    def param; 0; end
    
    def name
      "root"
    end
    
    def free_quota
      @api.getFreeUsageQuotaThisMonth
    end
    
#    attr_reader :cache_path
  end
  
  
  class Campaign < AdWords::CampaignService::Campaign   
    include ElementModule
    setup_element [:AdGroup]
    
    # Cache this?
    def optimize
      getOptimizeAdServing(@id)
    end
    
     def optimize=(val)
      setOptimizeAdServing(@id, val)
    end
  end
  
  class CampaignList # < AdWords::GetAllAdWordsCampaignsResponse
    include ListModule
    setup_list :getAllAdWordsCampaigns, Campaign
    
    def stats(start, stop)
      @api.send("get#{@child_class}Stats", @list.collect { |e| e.id }, start, stop, false)
    end
    
    def apply_update(list)
      if list.size == 1
        [@api.send("updateCampaign", list.first)]
      else
        @api.send("updateCampaignList", list)
      end
    end
    
    def apply_add(list)
      if list.size == 1
        [@api.send("addCampaign", list.first)]
      else
        @api.send("addCampaignList", list)
      end
    end
    
    def apply_delete(list)
      apply_update(list.collect { |e| e.status ='Deleted'; e})
    end
  end


  class AdGroup < AdWords::AdGroupService::AdGroup   
    include ElementModule
    setup_element [:Criterion, :TextAd]

    def param
      [@id]
    end
  end  
  
  class AdGroupList # < AdWords::GetAllAdGroupsResponse
    include ListModule
    setup_list :getAllAdGroups, AdGroup
        
#    def get_by_name(name, cpc = 1000000)
#      adgroup = find_by_name(name)
#      return adgroup if adgroup
#      adgroup = create
#      adgroup.name = name
#      adgroup.maxCpc = cpc
#      adgroup.status = 'Paused'
#      adgroup.save
#      adgroup
#    end
#    
    def apply_update(list)
      if list.size == 1
        [@api.send("updateAdGroup", list.first)]
      else
        @api.send("updateAdGroupList", list)
      end
    end
    
    def apply_add(list)
      if list.size == 1
        [@api.send("addAdGroup", @parent.id, list.first).addAdGroupReturn]
      else
        @api.send("addAdGroupList", @parent.id, list)
      end
    end
    
    def apply_delete(list)
      apply_update(list.collect { |e| e.status ='Deleted'; e})
    end
  end
  

#  class TextAd < AdWords::AdService::TextAd
#    include ElementModule
#    setup_element
#  end
  
  class TextAdList # < AdWords::GetAllCreativesResponse
    include ListModule
    setup_list :getActiveAds, AdWords::AdService::TextAd
    
    def set_values(list)
      list.collect do |cre|
        cre.adGroupId = @parent.id
        cre
      end
    end
    
    def apply_add(list)
      list = set_values(list)
#      puts "Call addAds: #{list.inspect}"
      begin
        @api.send("addAds", list)
      rescue AdWords::Error::ApiError => e
        puts "Detail: #{e.detail}"
        raise
      end
    end

    def apply_delete(list)
      list.each do |e|
        e.status = 'Disabled'
      end
      @api.updateAds(list)
      list
    end
    
#    def apply_delete(list)
#      if list.size == 1
#        [@api.send("deleteCreative", @parent.id, list.first)]
#      else
#        @api.send("deleteCreativeList",
#                  list.collect { |e| @parent.id },
#                  list.collect { |e| e.id })
#      end   
 #   end
  end


#  class Keyword < AdWords::CriterionService::Keyword
#    @@defaults = { :criterionType => 'Keyword' }
#  
#    include ElementModule
#    setup_element
#  end
  
  class CriterionList # < AdWords::GetAllCriteriaResponse
    include ListModule
    setup_list :getAllCriteria, AdWords::CriterionService::Keyword
    
#    def process_return(list)
#      puts "Processing Return: #{list.inspect}"
#      list.collect do |crit|
#        case crit.criterionType
#          when "Keyword"
#            keyword = AdWords::Keyword.new
#            keyword.copy_instance_variables_from(crit)
#            keyword
#          else
#            crit
#        end
#      end
#    end
    
    def update_compare(l, r)
      %w(adGroupId criterionType language negative text type).each do |attr|
        return nil unless l.send(attr) == r.send(attr)
      end
      true
    end

    def update_apply(dst, src)
      %w(destinationUrl maxCpc maxCpm paused).each do |attr|
        dst.send("#{attr}=", src.send(attr))
      end
      dst
    end
    
    def set_type(list)
      list.collect do |crit|
        crit.criterionType = "Keyword"
        crit.adGroupId = @parent.id
        crit
      end      
    end
    
    def apply_update(list)
      begin
        @api.send("updateCriteria", set_type(list))
        list
      rescue AdWords::Error::ApiError => e
        puts "List: #{list.collect {|i| i.text}.inspect}"
        puts "Detail: #{e.detail}"
        raise
      end
    end
    
    def apply_add(list)
      begin
        @api.send("addCriteria", set_type(list))  
      rescue AdWords::Error::ApiError => e
        puts "List: #{list.collect {|i| i.text}.inspect}"
        puts "Detail: #{e.detail}"
        raise
      end
    end
    
    def apply_delete(list)
      @api.send("removeCriteria", @parent.id, list.collect { |e| e.id })
      list
    end
  end
end
