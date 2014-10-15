require 'test_helper'
require 'borrow_direct/request'


VCRFilter.sensitive_data! :bd_library_symbol, :bd_request
VCRFilter.sensitive_data! :bd_finditem_patron, :bd_request


SUCCESSFUL_ITEM_ISBN = "9810743734"


describe "Request", :vcr => {:tag => :bd_request} do


  it "raises on bad path"  do
    assert_raises(BorrowDirect::HttpError) do
      response = BorrowDirect::Request.new("/no/such/path").request( "foo" => "bar" )
    end
  end

  it "raises on bad request hash" do
    assert_raises(BorrowDirect::HttpError) do
      response = BorrowDirect::Request.new("/dws/item/available").request( "foo" => "bar" )
    end
  end

  it "gets BD error info" do
    request = {
        "PartnershipId" => "BAD_ID",
        "Credentials" => {
            "LibrarySymbol" => "librarySymbol",
            "Barcode" => "barcode/patronId"
        },
        "ExactSearch" => [
            {
                "Type" => "type",
                "Value" => "value"
            }
        ]
    }

    e = assert_raises(BorrowDirect::Error) do
      response = BorrowDirect::Request.new("/dws/item/available").request( request )      
    end

    refute_nil e
    refute_nil e.message
    refute_nil e.bd_code
  end

  it "can make a succesful request" do
      request = {
          "PartnershipId" => "BD",
          "Credentials" => {
              "LibrarySymbol" => VCRFilter[:bd_library_symbol],
              "Barcode" => VCRFilter[:bd_finditem_patron]
          },
          "ExactSearch" => [
              {
                  "Type" => "ISBN",
                  "Value" => SUCCESSFUL_ITEM_ISBN
              }
          ]
      }

      
    response = BorrowDirect::Request.new("/dws/item/available").request( request )      
  end

  it "uses timeout for HttpClient" do
    request = BorrowDirect::Request.new("/some/path")
    request.timeout = 5

    http_client = request.send(:http_client!)

    assert_equal 5, http_client.send_timeout
    assert_equal 5, http_client.receive_timeout
    assert_equal 5, http_client.connect_timeout
  end

  describe "with expected errors" do
    it "still returns result" do
      request = {
          "PartnershipId" => "BAD_ID",
          "Credentials" => {
              "LibrarySymbol" => "librarySymbol",
              "Barcode" => "barcode/patronId"
          },
          "ExactSearch" => [
              {
                  "Type" => "type",
                  "Value" => "value"
              }
          ]
      }

      bd = BorrowDirect::Request.new("/dws/item/available")
      bd.expected_error_codes << "PUBFI003"
      response = bd.request( request )      

      assert_present response
    
    end
  end    

end