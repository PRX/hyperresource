require "test_helper"

describe HyperResource do
  before do
    @rsrc = HyperResource.new(root: "http://example.com", href: "/obj1/")
    @rsrc.adapter.apply(HAL_BODY, @rsrc)
  end

  describe "method_missing" do
    it "uses method_missing on :attr methods" do
      _(@rsrc.attr1).must_equal "val1"
      _(@rsrc.attributes.attr1).must_equal "val1"
      _(@rsrc.attr2).must_equal "val2"
      _(@rsrc.attributes.attr2).must_equal "val2"
    end

    it "uses method_missing on :attr= methods" do
      @rsrc.attr1 = :foo
      _(@rsrc.attr1).must_equal :foo
    end

    it "uses method_missing on :attr= methods for attributes with nil value" do
      @rsrc.attr3 = :foo
      _(@rsrc.attr3).must_equal :foo
    end

    it "uses method_missing on :link methods" do
      _(@rsrc.self).must_be_instance_of HyperResource::Link
      _(@rsrc.links.self).must_be_instance_of HyperResource::Link
    end

    it "uses method_missing on :obj methods" do
      _(@rsrc.obj1s).must_be_instance_of Array
      _(@rsrc.objects.obj1s).must_be_instance_of Array
    end
  end

  describe "Enumerable support" do
    it "implements each" do
      vals = []
      @rsrc.each { |r| vals << r.attr3 }
      _(vals).must_equal ["val3", "val5"]
    end

    it "supports []" do
      _(@rsrc.first).must_equal @rsrc[0]
    end

    it "supports map" do
      _(@rsrc.map(&:attr3)).must_equal ["val3", "val5"]
    end
  end

  describe "#to_link" do
    it "converts into a link" do
      link = @rsrc.send :to_link
      _(link.href).must_equal @rsrc.href
    end
  end
end
