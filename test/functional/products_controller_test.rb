require File.dirname(__FILE__) + '/../test_helper'

class ProductsControllerTest < ActionController::TestCase
  def test_main
    Product.find(:all, :order => "id").each do |product|
#      begin
        puts "Product: #{product.id}"
        get :main, :id => product.id
        assert_response :success
#      rescue
#        raise
#      end
    end
  end
end
