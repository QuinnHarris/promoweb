class Admin::SuppliersController < Admin::BaseController 
  def index
    suppliers = Supplier.find(:all,
                               :order => 'name')
#                                   :page => params[:page] || 1)

    @suppliers = {}
    suppliers.each { |s| @suppliers[s.parent_id] = (@suppliers[s.parent_id] || []) + [s] }
  end

  def detail
    if params[:id]
      @supplier = Supplier.find(params[:id])
      @address = @supplier.address
    else
      @supplier = Supplier.new
    end
    
    if request.post?
      @supplier.attributes = params[:supplier]
      @supplier.address ||= Address.new
      @supplier.address.update_attributes!(params[:address])
      return unless @supplier.valid?
      @supplier.save!
      redirect_to :action => :index
    end
  end
end
