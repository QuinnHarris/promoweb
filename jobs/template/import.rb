class NewSupplier < GenericImport
  def initialize
    # List of URLS that will be fetched.  The resulting local files will be placed in @src_files
    @src_urls = [] 
    super "Supplier Name"
  end

  # Called to fetch any data necessary for parse_products.  Typically an XLS, CSV or XML file
  # This will override a method that will fetch anything in the @src_urls variable
  # Only import drivers that get their data from a static list of URLs will use this.
  def fetch_parse?

    # If return true a new file has been fetched and parse_products should be rerun.
    # Otherwise the cache of the result of parse_products can be used
  end 

  # Called to do the actual work
  def parse_products

    # This next method should be called for each product from the supplier
    # This block is used to improve error messages.  When you set pd.supplier_num, if there is an error anywhere in the block the message will include the supplier_num
    ProductDesc.apply(self) do |pd|
      pd.supplier_num = nil # Required - string.  Unique product identifier provided by the supplier
      pd.name = nil         # Required - string.  Name of the product
      pd.description = []   # Required - string or array.  If this is an array it will be turned into a string separated by \n newlines.
      pd.data = nil         # Optional - hash.  Additional arbitrary data that doesn't fit anywhere else.  Usually not used
      pd.supplier_categories = [['Bags', 'Tote Bags']] # List of categories this product belongs to as the supplier specifies.  Each category is itself a list as categories typically form a hierarchy and this list represents the path

      pd.tags = [] # List of tags for this product  Should be one of Special, MadeInUSA, Eco, Closeout, New or Kosher.  Can create new tags if needed but must have an associated icon.
      
      pd.lead_time.normal_min = nil # Optional - integer.  The minimum time required to produce this product
      pd.lead_time.normal_max = nil # Optional - integer.  The maximum time required to produce this product
      pd.lead_time.rush = nil       # Optional - integer.  The time required for a rush order, usually less than normal_min

      pd.package.units = nil   # Optional - integer.  Number of products in a single package
      pd.package.weight = nil  # Optional - float.  Weight in pounds (lbs) of a single package
      pd.package.height = nil  # Optional - float.  Dimensions of package in inches (in)
      pd.package.width = nil
      pd.package.length = nil

      # List of DecorationDesc objects representing each decoration type and location
      pd.decorations = [DecorationDesc.none]
      pd.decorations << DecorationDesc.new(:technique => technique, # Array of strings representing a technique already in the database
                                            :location => location,  # string describing the location of the decoraiton
                                            :limit => limit)        # The maximum number of units (typically colors) for this decoration
      # The pricing for each technique must be specified for each supplier separately typically in a decorations.rb file
      # A pricing definition for a decoration can be created with get_decoration that will return a valid value for the :technique property of DecorationDesc
      # This is only used when the decoration price is specified for each product.  Many times the price for a decoration will be the same for all products and not in the product data.
      pd.decorations << DecorationDesc.new(:technique => get_decoration(technique, fixed_price, marginal_price),
                                           :location => location,
                                           :limit => limit)

      # List of ImageNodeFetch objects representing all the images for this product that are not specific to a product variant
      pd.images = [ImageNodeFetch.new(unique_image_identifier, image_url, optional_image_tag)]

      # Hash of properties common to all product variants.  If a property is specific to a variant it can be specified with a VariantDesc object in the same way
      # Common properties are
      #  dimension - dimension or size of the object
      #  color - color of the product or variant
      #  swatch - image representing the color of the product (ImageNodeFetch object)
      #  memory - capacity of USB flash drive
      # You can specify any property name and value string
      pd.properties['dimension'] = parse_dimension(dimension_string)


      # PricingDesc object representing the price of this product.
      # Either use pd.pricing for set the pricing for each variant but not both
      pd.pricing 

      # Use this to add a price column to the pricing object
      pd.pricing.add(quantity, price, optional_code, optional_rounding_if_code) 
      pd.pricing.apply_code(code) # Generate costs from a multi column discount code
      pd.pricing.ltm(charge, optional_quantity) # Set less than miniumum charge and quantity
      pd.pricing.maxqty(optional_quantity) # Set the maximum quantity
      pd.pricing.eqp(optional_discount, optional_round) # Set costs as end quantity pricing from the price data
      pd.pricing.eqp_costs # Set costs as end quantity pricing from the cost data.
      

      # pd.variants is a list of VariantDesc object describing each product variant (typically different colors)
      pd.variants = object.collect do |obj|
        vd = VariantDesc.new(:supplier_num => variant_supplier_num)
        vd.images = [] # List of ImageNodeFetch objects specific to this variant just like pd.images
        vd.properties['color'] = color # Hash of properties specific to this variant just like pd.properties

        vd.pricing # Optional.  Either use variant pricing or product pricing but not both
      end
    end
  end
end
