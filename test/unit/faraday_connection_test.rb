require "test_helper"

describe HyperResource::Link do
  def connection(hr)
    hr.to_link.send(:faraday_connection)
  end

  it "does not share connections between different faraday_options" do
    one = HyperResource.new(root: "http://options.example.com/",
      faraday_options: {request: {timeout: 1}})
    two = HyperResource.new(root: "http://options.example.com/",
      faraday_options: {request: {timeout: 2}})
    _(connection(one).options.timeout).must_equal 1
    _(connection(two).options.timeout).must_equal 2
  end

  it "sends basic auth" do
    hr = HyperResource.new(root: "http://auth.example.com/",
      auth: {basic: ["user", "pass"]})
    sent = nil
    fc = connection(hr)
    fc.builder.adapter :test do |stub|
      stub.get("/") { |env|
        sent = env.request_headers["Authorization"]
        [200, {}, ""]
      }
    end
    fc.get("/")
    _(sent).must_equal "Basic #{["user:pass"].pack("m0")}"
  end

  describe "request bodies" do
    before do
      @sent = sent = {}
      @conn = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post("/") { |env|
            sent[:type] = env.request_headers["Content-Type"]
            [201, {}, ""]
          }
        end
      end
      HyperResource::Link.any_instance.stubs(:faraday_connection).returns(@conn)
    end

    it "are sent as application/json" do
      HyperResource.new(root: "http://example.com/").post_response("a" => 1)
      _(@sent[:type]).must_equal "application/json"
    end

    it "keep a configured Content-Type" do
      @conn.headers["Content-Type"] = "application/hal+json"
      HyperResource.new(root: "http://example.com/").post_response("a" => 1)
      _(@sent[:type]).must_equal "application/hal+json"
    end
  end
end
