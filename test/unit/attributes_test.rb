require 'test_helper'

describe HyperResource::Attributes do
  class TestAPI < HyperResource; end

  describe 'accessors' do
    before do
      @rsrc = TestAPI.new(:root => 'http://example.com')
      @rsrc.adapter.apply(HAL_BODY, @rsrc)
      @attrs = @rsrc.attributes
    end

    it "provides access to all attributes" do
      _(@attrs.attr1).must_equal 'val1'
      _(@attrs.attr2).must_equal 'val2'
    end

    it 'supports null attributes' do
      _(@attrs.attr3).must_be_nil
    end

    it 'leaves _links and _embedded alone' do
      assert_raises NoMethodError do
        @attrs._links
      end
      assert_raises NoMethodError do
        @attrs._embedded
      end
    end

    it 'allows values to be changed' do
      @attrs.attr1 = :foo
      _(@attrs.attr1).must_equal :foo
    end
  end

  describe 'changed' do
    before do
      @rsrc = TestAPI.new
      @rsrc.adapter.apply(HAL_BODY, @rsrc)
    end

    it 'marks attributes as changed' do
      _(@rsrc.changed?(:attr1)).must_equal false
      _(@rsrc.changed?).must_equal false
      @rsrc.attr1 = :wowie_zowie
      _(@rsrc.changed?(:attr1)).must_equal true
      _(@rsrc.changed?(:attr2)).must_equal false
      _(@rsrc.changed?).must_equal true
    end
  end

end
