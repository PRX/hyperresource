require "test_helper"
require "rackup"
require "json"
require File.expand_path("../live_test_server.rb", __FILE__)

if ENV["NO_LIVE"]
  puts "Skipping live tests."
  exit
elsif RUBY_VERSION[0..2] == "1.8"
  puts "Live tests don't run on Ruby 1.8; skipping."
  exit
end

launched_server = false
server_thread = nil

HR_TEST_PORT = ENV["HR_TEST_PORT"] || 25491

class WhateverAPI < HyperResource; end

Minitest.after_run do
  server_thread.kill
end

describe HyperResource do
  before do
    unless launched_server
      server_thread = Thread.new do
        Rackup::Handler::WEBrick.run(
          LiveTestServer.new,
          Port: HR_TEST_PORT,
          AccessLog: [],
          Logger: WEBrick::Log.new(File::NULL, 7)
        )
      end

      retries = 5
      begin
        HyperResource.new(root: "http://localhost:#{HR_TEST_PORT}").get
      rescue => e
        if ENV["DEBUG"]
          puts "#{e.class}: #{e}" if ENV["DEBUG"]
          puts caller[0..10]
          retries -= 1
          raise e if retries == 0
        end
        sleep 0.2
        retry if retries > 0
      end

      launched_server = true
    end
  end

  private

  def make_new_api_resource
    WhateverAPI.new(root: "http://localhost:#{HR_TEST_PORT}/")
  end

  def expect_deprecation(rsrc)
    rsrc.class.expects(:_hr_deprecate).returns(true)
  end

  public

  describe "live tests" do
    it "works at all" do
      root = make_new_api_resource.get
      _(root).wont_be_nil
      _(root.name).must_equal "whatever API"
      _(root).must_be_kind_of HyperResource
      _(root).must_be_instance_of WhateverAPI::Root
    end

    it "follows links" do
      root = make_new_api_resource.get
      _(root.links).must_respond_to :widgets
      widgets = root.widgets.get
      _(widgets).must_be_kind_of HyperResource
      _(widgets).must_be_instance_of WhateverAPI::WidgetSet
    end

    it "loads resources automatically from method_missing" do
      api = make_new_api_resource
      _(api.widgets).wont_be_nil
    end

    it "observes proper classing" do
      api = make_new_api_resource
      _(api).must_be_instance_of WhateverAPI
      root = api.get
      _(root).must_be_instance_of WhateverAPI::Root
      _(root.links).must_be_instance_of WhateverAPI::Root::Links
      _(root.attributes).must_be_instance_of WhateverAPI::Root::Attributes

      _(root.widgets).must_be_instance_of WhateverAPI::Root::Link
      _(root.widgets.first.class.to_s).must_equal "WhateverAPI::Widget"
    end

    it "sends default_attributes" do
      api = make_new_api_resource
      api.default_attributes = {a: "b"}
      root = api.get
      _(root.sent_params).must_equal({"a" => "b"})
    end

    it "can update (DEPRECATED)" do
      root = make_new_api_resource.get
      widget = root.widgets.first
      widget.name = "Awesome Widget dood"
      expect_deprecation(widget)
      resp = widget.update
      _(resp.attributes).must_equal widget.attributes
      _(resp).wont_equal widget
    end

    it "can create (DEPRECATED)" do
      widget_set = make_new_api_resource.widgets.get
      expect_deprecation(widget_set)
      new_widget = widget_set.create(name: "Cool Widget brah")
      _(new_widget.class.to_s).must_equal "WhateverAPI::Widget"
      _(new_widget.name).must_equal "Cool Widget brah"
    end

    it "can delete" do
      root = make_new_api_resource.get
      widget = root.widgets.first
      del = widget.delete
      _(del.class.to_s).must_equal "WhateverAPI::Message"
      _(del.message).must_equal "Deleted widget."
    end

    it "can post without implicitly performing a get" do
      link = make_new_api_resource.post_only_widgets
      widget = link.post(name: "Cool Widget brah")
      _(widget.class.to_s).must_equal "WhateverAPI::PostOnlyWidget"
      _(widget.name).must_equal "Cool Widget brah"
    end

    it "caches headers separately across instances" do
      api1 = HyperResource.new(
        root: "http://localhost:#{HR_TEST_PORT}/conditional_widgets"
      )
      _(api1.get.type).must_equal "antiwidget"

      api2 = HyperResource.new(
        root: "http://localhost:#{HR_TEST_PORT}/conditional_widgets",
        headers: {"WIDGET" => "true"}
      )
      _(api2.get.type).must_equal "widget"
    end

    describe "invocation styles" do
      it "can use HyperResource with no namespace" do
        api = HyperResource.new(root: "http://localhost:#{HR_TEST_PORT}/")
        root = api.get
        _(root.loaded).must_equal true
        _(root.class.to_s).must_equal "HyperResource"
      end

      it "can use HyperResource with a namespace" do
        api = HyperResource.new(root: "http://localhost:#{HR_TEST_PORT}/",
          namespace: "NsTestApi")
        root = api.get
        _(root.loaded).must_equal true
        _(root.class.to_s).must_equal "NsTestApi::Root"
      end

      class NsExtTestApi < HyperResource
        class Root < NsExtTestApi
          def foo
            :foo
          end
        end
      end
      it "can use HyperResource with a namespace which is extended" do
        api = HyperResource.new(root: "http://localhost:#{HR_TEST_PORT}/",
          namespace: "NsExtTestApi")
        root = api.get
        _(root.loaded).must_equal true
        _(root.class.to_s).must_equal "NsExtTestApi::Root"
        _(root).must_respond_to :foo
        _(root.foo).must_equal :foo
      end

      class SubclassTestApi < HyperResource
        self.root = "http://example.com"
      end
      it "can use a subclass of HR" do
        ## Test class-level setter
        api = SubclassTestApi.new
        _(api.root).must_equal "http://example.com"

        SubclassTestApi.root = "http://localhost:#{HR_TEST_PORT}/"
        api = SubclassTestApi.new
        root = api.get
        _(root.loaded).must_equal true
        _(root.class.to_s).must_equal "SubclassTestApi::Root"
      end
    end

    describe "configuration testing" do
      before do
        @new_api_resource_short = WhateverAPI.new(
          root: "http://localhost:#{HR_TEST_PORT}/",
          faraday_options: {
            request: {timeout: 0.5, open_timeout: 2}
          }
        )
      end

      it "accepts custom timeout parameters" do
        p = proc { @new_api_resource_short.get.slow_widgets.first }
        if defined?(Faraday::TimeoutError)
          _(p).must_raise(Faraday::TimeoutError)
        elsif defined?(Faraday::Error::TimeoutError)
          _(p).must_raise(Faraday::Error::TimeoutError)
        else
          raise "Unknown version of Faraday."
        end
      end

      it "passes the configuration to subclasses" do
        api_short_child = @new_api_resource_short.get
        _(api_short_child.faraday_options[:request][:timeout]).must_equal 0.5
      end
    end
  end # describe 'live tests'
end # describe HyperResource
