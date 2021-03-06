module ObjectTaskMixin  
  module ClassMethods
    def has_tasks
      table_name = Kernel.const_get("#{self}Task").table_name
      has_many :tasks_active, :class_name => "#{self}Task", :order => 'created_at DESC', :conditions => "#{table_name}.active"
      has_many :tasks_inactive, :class_name => "#{self}Task", :order => 'created_at DESC', :conditions => "#{table_name}.active IS NULL"
      has_many :tasks_other, :class_name => "#{self}Task", :order => 'created_at DESC', :conditions => "NOT #{table_name}.active"
    end
  end
  
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  def task_recent
    tasks_active.to_a.sort { |l, r| r.updated_at <=> l.updated_at }.first
  end
 
  def task_completed?(task_class)
    raise "Not correct task class: #{task_class} not a #{self.class}Task" unless task_class.superclass == Kernel.const_get("#{self.class}Task")
    tasks_active.to_a.find { |t| t.is_a?(task_class) }
  end

  def task_performed?(task_class)
    task_completed?(task_class) || tasks_inactive.find(:first, :conditions => "type = '#{task_class}'")
  end

  def task_revokable?(task_class)
    tasks_context.find { |t| t.is_a?(task_class) }.revokable?
  end
  
  def task_next(permissions, reject = [])
    tasks_context.find do |t|
      t.ready? and t.customer and !reject.include?(t.class) and !(t.roles & permissions).empty? and (!block_given? or yield(t))
    end
  end

  def tasks_ready
    tasks_context.find_all { |t| t.ready? and t.waiting_name }
  end

  # Only used by assemble_dep  
  def task_find(task_class)
    tasks_active.to_a.find { |t| t.is_a?(task_class) }
  end

  def tasks_new
    return @tasks_new if @tasks_new
    @tasks_new = []
  end

  def task_find_all(task_class)
#    unless @task_map
#      @task_map = {}
#      (tasks_active.to_a + tasks_other.to_a).reverse.each do |task|
#        @task_map[task.class] = task
#      end
#    end
#    t = tasks_new.find { |t| t.is_a?(task_class) }
#    return t if t
#    @task_map[task_class]
    (tasks_active.to_a + tasks_new + tasks_other.to_a).find { |t| t.is_a?(task_class) }
  end

  # Only used by _pending_tasks.haml
  def task_find_inactive(task_class)
    task_class.find(:first, :order => 'id DESC',
                    :conditions => ["#{task_class.reflections[:object].association_foreign_key} = ? AND active IS NULL", id])
  end

  
  def task_ready?(task_class, inject = [])
    return nil unless task_object = tasks_context.find { |t| t.is_a?(task_class) }
    task_object.ready?(inject)
  end

  def task_blocked?(task_class, inject = [])
    return nil unless task_object = tasks_context.find { |t| t.is_a?(task_class) }
    task_object.class.blocked(self)
  end
  
  def task_ready_completed?(task_class, inject = [])
    task_ready?(task_class, inject) or task_completed?(task_class)
  end
  
  # if revokable = nil then revoke without considering dependancies
  def task_revoke(tasks_revoke, data_inject = nil)
    tasks_revoke = [tasks_revoke].flatten.uniq
    task_object =  tasks_context.find { |t| t.is_a?(tasks_revoke.first) }
    return nil unless task_object and task_object.active

    unless task_object.revokable?(tasks_revoke[1..-1])
      raise "Task unrevoke: #{task_object} #{tasks_revoke.collect { |t| t.name }.inspect}"
    end
        
    primary_task = nil
    OrderTask.transaction do
      tasks_context.each do |task|
        next unless !task.new_record? and task.active and tasks_revoke.include?(task.class)

        task.active = nil

        if task.is_a?(tasks_revoke.first)
          primary_task = task 
          if data_inject
            raise "Task data must be hash instead #{task.data.inspect}" unless !task.data or task.data.is_a?(Hash)
            raise "Passed data must be hash instead #{data_inject}" unless data_inject.is_a?(Hash)
            task.data = task.data.merge(data_inject)
          end
        end
        task.save!
        tasks_active.target.delete(task)
      end
    end
    return primary_task
  end
  
  def task_complete(params, task_class, revokable = [], revoke = true)
    task = nil
    OrderTask.transaction do
      if reason = task_class.blocked(self)
        raise "Task Blocked #{task_class}: #{reason}"
      end

      if revoke
        task_revoke([task_class] + revokable)
      else
        if task_object = tasks_context.find { |t| t.is_a?(task_class) && t.active } # Should we have to test for active here?
#          raise "Task not active" unless task_object.active
          if revokable and !task_object.new_record? and !task_object.revokable?(revokable)
            raise "Task has unrevokable dependance: #{task_class} #{revokable.inspect}"
          end
          task_object.active = nil
          task_object.save!
        end
      end
      params[:data] = {:email_sent => true}.merge(params[:data] || {}) if task_class.method_defined?(:email_complete)

      task = tasks_context.to_a.find { |t| t.is_a?(task_class) } unless revoke
      unless task
        task = task_class.new
        tasks_active.target << task
      end
      task.active = true

      task.attributes = { reflections[:tasks_active].foreign_key => id }.merge(params)
      task.apply(params) if task.respond_to?(:apply)
      task.save!

      if params[:data] and params[:data][:email_sent]
        task.email_complete
      end
      if task.object.respond_to?(:user) and (task.notify or !task.roles.include?('Customer'))
        order = task.object
        order = order.order if order.respond_to?(:order)
        notify_users = [order.user].compact
        roles = task.roles
        roles += task.notify if task.notify.is_a?(Array)
        notify_users += User.find(:all, :include => :permissions,
          :conditions => ["permissions.order_id = ? AND permissions.name IN (?)", order.id, roles])
        notify_users.uniq!
        notify_users.delete(task.user)
        TaskNotify.notify(order, task, notify_users.collect { |u| u.email_string }).deliver unless notify_users.empty?
      end
    end
    task
  end

  def task_save(params, task_class)
    OrderTask.transaction do
      attributes = {
        task_class.reflections[:object].association_foreign_key => id,
        :active => false
      }
      if task = task_class.find(:first, :conditions => attributes)
        task.update_attributes!(params)
      else
        task_class.create(attributes.merge(params)) 
      end
    end
  end
end

class TaskSet
  @@set = []
  def self.add_task(task)
    @@set << task
  end
  cattr_reader :set
  
  def self.order(list)
    list.sort do |l, r|
      next l.object.id <=> r.object.id if l.class == r.class
#      next 0 if l.class == r.class
      @@set.index(l.class) <=> @@set.index(r.class)
    end
  end
  
  def self.test(list)
    if list.is_a?(Array)
      list.each { |c| raise "TaskSet: not in set: #{c.inspect}" unless @@set.index(c) }
    else
      raise "TaskSet: not in set: #{list.inspect}" unless @@set.index(list)
    end
  end
end

module TaskMixin
  module ClassMethods   
    #attr_accessor :depends_on
    def set_depends_on(*list)
      @depends_on = list
      list.flatten.each { |d| d.add_dependant(self) }
    end
    def depends_on
      @depends_on || []
    end
 
    def add_dependant(dep)
      @dependants ||= []
      @dependants << dep
    end
    
    def dependants
      @dependants || []
    end
    def all_dependants
      return nil unless dependants
      (dependants + dependants.collect { |d| d.all_dependants }).flatten
    end
    
    attr_accessor :status_name
    attr_accessor :waiting_name
    attr_accessor :completed_name
    attr_accessor :action_name
    attr_accessor :option
    attr_accessor :customer
    attr_accessor :uri
    attr_accessor :auto_complete
    attr_accessor :notify
    attr_writer :roles
    def roles
      [self.to_s, 'Super'] + (@roles || [])
    end
    def allowed?(perms)
      not (roles & perms).empty?
    end
    
    def blocked(object)
      object = object.order if object.respond_to?(:order)
      (object.respond_to?(:closed) && object.closed) ? "Order Closed" : nil
    end
          
    # All context objects have only one of type per object
    # Target is task for object
    def assemble_deps(context, object, target_class)
      if target_task = object.task_find_all(target_class)
        return [target_task, []] if target_task.depends_on
      else
        object.tasks_new << target_task = target_class.new(:object => object)
      end

      task_list = [target_task]

#      s = Benchmark.measure do
      
      target_task.depends_on = []
      target_class.depends_on.each do |task_class_list|
        task_class_list = [task_class_list].flatten

        # Find active dependant task
        task_context = nil
        task_class = task_class_list.reverse.find do |task_class|
          task_context = (context + [object]).find do |obj|
            obj.task_find(task_class)
          end
        end

        if task_class and !target_task.new_record? and target_task.active
          # If current and dependant are active
          # use single active dependant
          task_class_list = [task_class]
          task_context_list = [task_context]
        else
          # Enumerate all dependants
          task_context_list = task_class_list.collect do |t_class|
            context_class = t_class.reflections[:object].klass
            (context + [object]).find do |obj|
              obj.is_a?(context_class)
            end
          end
          
          if task_class
            # If active dependant but current not active
            # Enumerate all prior incomplete tasks
            index = task_class_list.index(task_class)
            task_class_list = task_class_list[index..-1]
            task_context_list = task_context_list[index..-1]
          else
            task_class = task_class_list.first
          end
        end
        
        unless task_context_list.compact.empty?
          task_class_list.zip(task_context_list).each do |t_class, task_context|
            tt, list = assemble_deps(context, task_context, t_class)
            task_list += list
            if t_class == task_class
              # Only include single task_class
              target_task.depends_on << tt
            else
              # Add dependant here as its not in depends_on below
              tt.add_dependant(target_task)
            end
          end
        else
          raise "more than one task_class" unless task_class_list.length == 1
          # Must be child items
          target_task.depends_on +=
            object.items.collect do |obj|
              obj.tasks_active # Kludge to prevent two queries one for count
              tt, list = assemble_deps(context + [object], obj, task_class)
              task_list += list
              tt
            end.compact
        end
      end
      # Can remove if not triggered
      raise "Not flat" unless target_task.depends_on.flatten.length == target_task.depends_on.length
      target_task.depends_on.each { |t| t.add_dependant(target_task) }

#      end
#      logger.info("Bench: #{target_class} #{s}")
      
      [target_task, task_list]
    end
    
    def inherited(child)
      TaskSet.add_task(child)
      super
    end
  end
  
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  # dependants
  %w(status_name waiting_name completed_name action_name option customer uri auto_complete roles notify).each do |name|
    define_method name do
      self.class.send(name)
    end
  end
  def allowed?(perms)
    self.class.allowed?(perms)
  end

  attr_accessor :depends_on, :dependants
  def add_dependant(task)
    @dependants = (@dependants || []) + [task]
  end

  def all_dependants
    return nil unless dependants
    (dependants + dependants.collect { |d| d.all_dependants }).flatten
  end
  
  def delegatable_users(user_id)
    User.find(:all, :include => :delegatables,
      :conditions => ["users.id <> #{user_id} AND users.id NOT IN (SELECT user_id FROM permissions WHERE order_id = #{object.id || 0}) AND delegatables.name IN (?)", roles])
  end
  
  # Methods for status table
  def set_cols(visible, list)
    @rows = 1 if visible
    @cols = (depends_on & list).find_all { |u| u.visible }.inject(0) { |s, v| s + (v.cols || 0) }
    @cols = 1 if @cols == 0 and visible
  end
  def inc_rows; @rows += 1; end
  def visible; !@rows.nil?; end
  attr_reader :rows
  attr_accessor :cols
  
  
  def ready?(inject = [])
    return nil unless new_record? or !active   
    not depends_on.find do |task|
      not ((!task.new_record? and task.active) or
           (inject.include?(task.class) and task.ready?(inject - [task.class])))
    end
  end
  
  def revokable?(reject = [])
    return false unless active
    return true unless dependants
    not dependants.find { |t| !t.new_record? and t.active and !(reject.include?(t.class) and t.revokable?(reject)) }
  end
  
  def ready_given?(list)
    not depends_on.find do |task|
      not list.index(task)
    end
  end
  
  def status; nil; end
  def admin; nil; end
    
  def complete_estimate
    return nil if option
    if respond_to?(:execute_duration)
      return depend_max_at.add_workday(execute_duration)
    end
    dependants && dependants.first.depends_on.collect { |t| (t != self && !t.new_record? && t.active) ? t.created_at : nil }.compact.max
  end
  def complete_at
    return nil if option
    return expected_at if expected_at
    return created_at if !new_record? and active
    complete_estimate
  end
  def late
    return nil if !new_record? and active
    ca = complete_at
    ca < Time.now.utc if ca
  end
  
  def depend_max_at
    depends_on && depends_on.collect { |t| t.complete_at }.compact.max || Time.now.utc
  end
end


class CustomerTask < ActiveRecord::Base
  belongs_to :object, :class_name => 'Customer', :foreign_key => 'customer_id'
  belongs_to :user
  
  include TaskMixin

  self.roles = %w(Customer Orders)
end

class CustomerMergeTask < CustomerTask
  self.completed_name = 'Merged Customer'
  self.roles = %w(Orders)
end
