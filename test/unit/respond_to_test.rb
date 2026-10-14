require "test_helper"

describe HyperResource do
  class NoMethodsAPI < HyperResource; end

  before do
    @api = NoMethodsAPI.new(root: "http://example.com")
    @api.adapter.apply(HAL_BODY, @api)
  end

  describe "respond_to" do
    it "doesn't create methods" do
      _(@api.methods).wont_include(:attr1)
      _(@api.attributes.methods).wont_include(:attr1)
      _(@api.methods).wont_include(:obj1s)
      _(@api.objects.methods).wont_include(:obj1s)
      _(@api.methods).wont_include(:foobars)
      _(@api.links.methods).wont_include(:foobars)
    end

    it "responds_to the right things" do
      _(@api).must_respond_to(:attr1)
      _(@api.attributes).must_respond_to(:attr1)
      _(@api).must_respond_to(:obj1s)
      _(@api.objects).must_respond_to(:obj1s)
      _(@api).must_respond_to(:foobars)
      _(@api.links).must_respond_to(:foobars)
    end
  end
end
