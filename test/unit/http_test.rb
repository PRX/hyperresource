require "test_helper"

stub_connection = Faraday.new do |builder|
  builder.adapter :test do |stub|
    stub.get("/") {
      [200, {"Content-type" => "application/vnd.dummy.v1+hal+json;type=Root"},
        <<~EOT
          { "name":"Stub API",
            "_links": {
              "self": {"href": "/"},
              "dummies": {"href": "/dummies{?email,name}", "templated": true}
            }
          }
        EOT
    ]
    }

    joe_dummy = <<~EOT
      { "first_name": "Joe", "last_name": "Dummy",
        "_links": {
          "self": {"href": "/dummies/1"},
          "root": {"href": "/"}
        }
      }
    EOT

    stub.get("/dummies") {
      [200, {"Content-type" => "application/vnd.dummy.v1+hal+json;type=Dummies"},
        <<~EOT
          { "_embedded": { "dummies": [ #{joe_dummy} ] },
            "_links": {
              "self": {"href": "/dummies"},
              "root": {"href": "/"}
            }
          }
        EOT
    ]
    }

    stub.post("/dummies") {
      [
        201,
        {"Content-type" => "application/vnd.dummy.v1+hal+json;type=Dummies",
         "Location" => "/dummies/1"},
        joe_dummy
      ]
    }

    stub.get("/dummies/1") {
      [
        200,
        {"Content-type" => "application/vnd.dummy.v1+hal+json;type=Dummy"},
        joe_dummy
      ]
    }

    stub.put("/dummies/1") {
      [
        200,
        {"Content-type" => "application/vnd.dummy.v1+hal+json;type=Dummy"},
        joe_dummy
      ]
    }

    stub.patch("/dummies/1") {
      [
        200,
        {"Content-type" => "application/vnd.dummy.v1+hal+json;type=Dummy"},
        joe_dummy
      ]
    }

    stub.delete("/dummies/1") {
      [
        200,
        {"Content-type" => "application/vnd.dummy.v1+hal+json"},
        ""
      ]
    }

    # from Rack specs 'Content-type' => 'application/vnd.dummy.v1+hal+json'
    stub.get("/204_with_nil_body") {
      [
        204,
        {},
        nil
      ]
    }
    stub.get("/204_with_empty_string_body") {
      [
        204,
        {},
        ""
      ]
    }

    stub.get("/204_with_empty_hash_body") {
      [
        204,
        {},
        {}
      ]
    }

    stub.get("/404") {
      [
        404,
        {"Content-type" => "application/vnd.dummy.v1+hal+json;type=Error"},
        '{"error": "Not found", "_links": {"root":{"href":"/"}}}'
      ]
    }

    stub.get("/405_without_body") {
      [
        405,
        {"Content-type" => "application/vnd.dummy.v1+hal+json;type=Error"},
        '""'
      ]
    }

    stub.get("/500") {
      [
        500,
        {"Content-type" => "application/vnd.dummy.v1+hal+json;type=Error"},
        '{"error": "Internal server error", "_links": {"root":{"href":"/"}}}'
      ]
    }

    stub.get("/garbage") {
      [
        200,
        {"Content-type" => "application/json"},
        '!@#$%!@##%$!@#$%^  (This is very invalid JSON)'
      ]
    }
  end
end

describe HyperResource::Modules::HTTP do
  class DummyAPI < HyperResource
    class Link < HyperResource::Link
    end
  end

  before do
    DummyAPI::Link.any_instance.stubs(:faraday_connection).returns(stub_connection)
  end

  describe "GET" do
    it "works at a basic level" do
      hr = DummyAPI.new(root: "http://example.com/")
      root = hr.get
      _(root).wont_be_nil
      _(root).must_be_kind_of HyperResource
      _(root).must_be_instance_of DummyAPI::Root
      _(root.links).must_be_instance_of DummyAPI::Root::Links
      assert root.links.dummies
    end

    it "raises client error" do
      hr = DummyAPI.new(root: "http://example.com/", href: "404")
      begin
        hr.get
        assert false # shouldn't get here
      rescue HyperResource::ClientError => e
        _(e.response).wont_be_nil
      end
    end

    it "Accepts response without a body (example status 204 with nil body)" do
      hr = DummyAPI.new(root: "http://example.com/", href: "204_with_nil_body")
      root = hr.get
      _(root).wont_be_nil
      _(root.links).must_be_empty
      _(root.attributes).must_be_empty
      _(root.objects).must_be_empty
      _(root).must_be_kind_of HyperResource
      _(root).must_be_instance_of DummyAPI

      _(root.response.status).must_equal 204
      _(root.response.body).must_be_nil
    end

    it "Accepts response without a body (example status 204 with empty string body)" do
      hr = DummyAPI.new(root: "http://example.com/", href: "204_with_empty_string_body")
      root = hr.get
      _(root).wont_be_nil
      _(root.links).must_be_empty
      _(root.attributes).must_be_empty
      _(root.objects).must_be_empty
      _(root).must_be_kind_of HyperResource
      _(root).must_be_instance_of DummyAPI

      _(root.response.status).must_equal 204
      _(root.response.body).must_equal("")
    end

    it "Accepts response without a body (example status 204 with empty hash body)" do
      hr = DummyAPI.new(root: "http://example.com/", href: "204_with_empty_hash_body")
      root = hr.get
      _(root).wont_be_nil
      _(root.links).must_be_empty
      _(root.attributes).must_be_empty
      _(root.objects).must_be_empty
      _(root).must_be_kind_of HyperResource
      _(root).must_be_instance_of DummyAPI

      _(root.response.status).must_equal 204
      _(root.response.body).must_equal({})
    end

    it "raises client error and accepts empty body for a status 405" do
      hr = DummyAPI.new(root: "http://example.com/", href: "405_without_body")
      begin
        hr.get
        assert false # shouldn't get here
      rescue HyperResource::ClientError => e
        _(e.response).wont_be_nil
        _(e.response.status).must_equal 405
      end
    end

    it "raises server error" do
      hr = DummyAPI.new(root: "http://example.com/", href: "500")
      begin
        hr.get
        assert false # shouldn't get here
      rescue HyperResource::ServerError => e
        _(e.response).wont_be_nil
      end
    end

    it "raises response error" do
      hr = DummyAPI.new(root: "http://example.com/", href: "garbage")
      begin
        hr.get
        assert false # shouldn't get here
      rescue HyperResource::ResponseError => e
        _(e.response).wont_be_nil
        _(e.cause).must_be_kind_of Exception
      end
    end

    it "does get_response" do
      hr = DummyAPI.new(root: "http://example.com/")
      root = hr.get_response
      _(root).wont_be_nil
      _(root).must_be_kind_of Faraday::Response
    end
  end
end

describe 'HyperResource::Modules::HTTP#faraday_connection' do
  class ConnDummyAPI < HyperResource
    class Link < HyperResource::Link
    end
  end

  before do
    @requests = []
    requests = @requests
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get(/.*/) do |env|
        requests << env
        [200, {'Content-type' => 'application/json'}, '{}']
      end
    end
    @builder = Faraday::RackBuilder.new { |b| b.adapter :test, stubs }
  end

  def new_resource(href, opts={})
    ConnDummyAPI.new({
      :root => 'http://example.com/',
      :href => href,
      :faraday_options => {:builder => @builder}
    }.merge(opts))
  end

  it 'does not add entries to Thread.current' do
    ## Faraday 2 dropped Connection#basic_auth; stub it so rotating
    ## credentials can still be exercised here.
    Faraday::Connection.any_instance.stubs(:basic_auth)
    new_resource('/warmup').get_response
    keys_before = Thread.current.keys
    50.times do |i|
      new_resource("/items/#{i}?page=#{i}",
                   :headers => {'Authorization' => "Bearer token#{i}"},
                   :auth => {:basic => ["user#{i}", 'pass']}).get_response
    end
    @requests.length.must_equal 51
    (Thread.current.keys - keys_before).must_be_empty
  end

  it 'builds a new connection on every call' do
    link = new_resource('/items/1').to_link
    c1 = link.send(:faraday_connection)
    c2 = link.send(:faraday_connection)
    c1.wont_be_same_as c2
  end

  it 'sends requests to the right URL with the right headers' do
    new_resource('/items/1?a=b', :headers => {'X-Token' => 'one'}).get_response
    new_resource('/items/2', :headers => {'X-Token' => 'two'}).get_response

    @requests.length.must_equal 2
    @requests[0].url.to_s.must_equal 'http://example.com/items/1?a=b'
    @requests[0].request_headers['X-Token'].must_equal 'one'
    @requests[0].request_headers['User-Agent'].must_equal ConnDummyAPI.new.user_agent
    @requests[1].url.to_s.must_equal 'http://example.com/items/2'
    @requests[1].request_headers['X-Token'].must_equal 'two'
  end

  it 'applies basic auth for the URL' do
    link = new_resource('/items/1', :auth => {:basic => ['user', 'pass']}).to_link
    Faraday::Connection.any_instance.expects(:basic_auth).with('user', 'pass')
    conn = link.send(:faraday_connection)
    conn.url_prefix.to_s.must_equal 'http://example.com/items/1'
  end
end
