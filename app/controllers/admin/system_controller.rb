class Admin::SystemController < Admin::BaseController 
  def category_description
    Category.transaction do
      category = Category.find(params[:id])
      category.description = params[:category][:description]
      category.save!
    end
    redirect_to :back
  end
  
  def quickbooks_blocked
    @list = QbwcController.objects.collect do |klass|
      [klass,
       klass.find(:all, :order => 'id',
       :conditions => "quickbooks_at = 'infinity' OR ((quickbooks_id IS NOT NULL) AND quickbooks_at = '-infinity') OR quickbooks_id = 'INVALID'")]
    end
  end

  def quickbooks_set
    klass = Kernel.const_get(params[:class])
    case params[:mode]
    when 'reload'
      attrs = { :quickbooks_at => '-infinity' }
    when 'ignore'
      attrs = { :quickbooks_at => '3000-01-01' }
    else
      raise "Unkown mode: #{params[:mode].inspect}"
    end
    obj = klass.find(params[:id])
    attrs.merge!(:quickbooks_id => nil) if obj.quickbooks_id == 'INVALID'
    klass.update_all(attrs, { :id => obj.id})
    
    redirect_to :action => :quickbooks_blocked
  end
end
