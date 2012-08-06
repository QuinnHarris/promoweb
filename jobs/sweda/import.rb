class SwedaXML < GenericImport
  def initialize
    time = Time.now - 1.day
    @src_file = WebFetch.new('http://swedausa.com/uploads/ExportData/Products.xml').get_path(time)
    super 'Sweda'
  end

  def parse_products
    unique_columns = %w(ProductId Sku ColorCode ColorDesc VariantImage)
    common_columns = %w(SizeCode SizeDesc AdditionalPrice GrossWeight ColorSwatch ItemNo ProductName Description Specification Note RequestSample RelatedProducts TubeVideo SlideShow Thumbnail Image PdfFiles AdditionalImages MetaTitle MetaDesc MetaKeywords MetaPriority MetaPostDate ApplicationID ProductionTime ImprintArea VirtualLogo PackQty PackWeight ProductionMinTime ProductionMaxTime MaxOrder ApplicationName CATEGORY_NAME CloseOut BestSell NewArrive DisplayProduct IsSampleRequest Qty_Desc Qty_DisplayPoint1 Qty_Point1 Qty_Price1 Qty_Special1 Qty_DisplayPoint2 Qty_Point2 Qty_Price2 Qty_Special2 Qty_DisplayPoint3 Qty_Point3 Qty_Price3 Qty_Special3 Qty_DisplayPoint4 Qty_Point4 Qty_Price4 Qty_Special4 Qty_DisplayPoint5 Qty_Point5 Qty_Price5 Qty_Special5 Qty_DisplayPoint6 Qty_Point6 Qty_Price6 Qty_Special6 Qty_Col1Name Qty_Col1Price1 Qty_Col1Price2 Qty_Col1Price3 Qty_Col1Price4 Qty_Col1Price5 Qty_Col1Price6 Qty_Col2Name Qty_Col2Price1 Qty_Col2Price2 Qty_Col2Price3 Qty_Col2Price4 Qty_Col2Price5 Qty_Col2Price6 Qty_Col3Name Qty_Col3Price1 Qty_Col3Price2 Qty_Col3Price3 Qty_Col3Price4 Qty_Col3Price5 Qty_Col3Price6)
    product_merge = ProductRecordMerge.new(unique_columns, common_columns)

    CSV.foreach(@src_file, :headers => :first_row) do |row|
      product_merge.merge(row['ItemNo'], row)
    end
  end
end
