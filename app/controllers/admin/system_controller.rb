class Admin::SystemController < Admin::BaseController
  def quickbooks_blocked
    @title = "Quickbooks"

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

  def other

  end

  def bitcoind
    secrets = YAML.load_file("#{Rails.root}/config/secrets")
    bitsec = secrets['bitcoin']
                             
    @client = Bitcoin::Client.new(bitsec['user'], bitsec['password'])
    
  end
end
