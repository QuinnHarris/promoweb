class Admin::SuppliersController < Admin::BaseController 
  def index
    @title = "Suppliers"
    @static = !@permissions.include?('Super')

    suppliers = Supplier.find(:all,
                               :order => 'name')

    @suppliers = {}
    suppliers.each { |s| @suppliers[s.parent_id] = (@suppliers[s.parent_id] || []) + [s] }
  end

  def new
    @supplier = Supplier.new
    @address = @supplier.address = Address.new
  end
  def create
    @supplier = Supplier.new(params[:supplier])
    @supplier.address = Address.new(params[:address])

    if @supplier.save
      redirect_to(admin_suppliers_path,
                  :notice => 'Supplier created')
    else
      render :action => 'new'
    end
  end

  def edit
    @supplier = Supplier.find(params[:id])
    @address = (@supplier.address ||= Address.new)
  end
  def show
    redirect_to :action => :edit
  end

  def update
    Supplier.transaction do
      @supplier = Supplier.find(params[:id])
      @supplier.attributes = params[:supplier]
      @supplier.address ||= Address.new
      @supplier.address.update_attributes!(params[:address])
      return unless @supplier.valid?
      unless @supplier.price_source
        @supplier.price_source = PriceSource.create(:name => @supplier.name)
      end
      @supplier.save!
    end

    redirect_to(admin_suppliers_path,
                :notice => 'Supplier updated')
  end
end
