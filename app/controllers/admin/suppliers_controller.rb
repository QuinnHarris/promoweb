class Admin::SuppliersController < Admin::BaseController 
  def index
    @title = "Suppliers"

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

    @title = "Supplier: #{@supplier.name}"
    
    if request.post?
      Supplier.transaction do
        @supplier.attributes = params[:supplier]
        @supplier.address ||= Address.new
        @supplier.address.update_attributes!(params[:address])
        return unless @supplier.valid?
        unless @supplier.price_source
          @supplier.price_source = PriceSource.create(:name => @supplier.name)
        end
        @supplier.save!
      end
      redirect_to :action => :index
    end
  end
end
