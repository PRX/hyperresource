require "uri_template"
require "hyper_resource/modules/http"

class HyperResource
  ## HyperResource::Link is an object to represent a hyperlink and its
  ## URL or body parameters, and to encapsulate HTTP calls involving this
  ## link.  Links are typically created by HyperResource, not by end users.
  ##
  ## HTTP method calls return the response as a HyperResource (or subclass)
  ## object.  Calling an unrecognized method on a link will automatically
  ## load the resource pointed to by this link, and repeat the method call
  ## on the resource object.
  ##
  ## A HyperResource::Link requires the resource it is based upon to remain
  ## in scope.  In practice this is rarely a problem, as links are almost
  ## always accessed through the resource object.

  class Link
    include HyperResource::Modules::HTTP

    ## The literal href of this link; may be templated.
    attr_accessor :base_href

    ## An optional name describing this link.
    attr_accessor :name

    ## `true` if this link's href is a URI Template, `false` otherwise.
    attr_accessor :templated

    ## A hash of URL or request body parameters.
    attr_accessor :params

    ## Default HTTP method for implicit loading.
    attr_accessor :default_method

    ## The resource from which this link originates.
    attr_accessor :resource

    ## Returns a link based on the given resource and link specification
    ## hash.  `link_spec` keys are: `href` (string, required), `templated`
    ## (boolean), `params` (hash), and `default_method` (string, default
    ## `"get"`).
    def initialize(resource, link_spec = {})
      unless link_spec.is_a?(Hash)
        raise ArgumentError, "link_spec must be a Hash (got #{link_spec.inspect})"
      end
      link_spec = link_spec.map { |(k, v)| [k.to_s, v] }.to_h ## stringify keys

      self.resource = resource
      self.base_href = link_spec["href"]
      self.name = link_spec["name"]
      self.templated = !!link_spec["templated"]
      self.params = link_spec["params"] || {}
      self.default_method = link_spec["method"] || "get"
      @headers = link_spec["headers"] || {}
    end

    ## Returns this link's href, applying any URI template params.
    def href
      if templated
        filtered_params = resource.outgoing_uri_filter(params)
        URITemplate.new(base_href).expand(filtered_params)
      else
        base_href
      end
    end

    ## Returns this link's fully resolved URL, or nil if `resource.root`
    ## or `href` are malformed.
    def url
      URI.join(resource.root, href.to_s).to_s
    rescue
      nil
    end

    ## Returns a new scope with the given params; that is, returns a copy of
    ## itself with the given params applied.
    def where(params)
      params = params.map { |(k, v)| [k.to_s, v] }.to_h
      self.class.new(resource,
        "href" => base_href,
        "name" => name,
        "templated" => templated,
        "params" => self.params.merge(params),
        "method" => default_method,
        "headers" => @headers)
    end

    ## When called with a hash, returns a new scope with the given headers;
    ## that is, returns a copy of itself with the given headers applied.
    ## These headers will be merged with `resource.headers` at request time.
    ##
    ## When called with no arguments, returns the headers for this link.
    def headers(*args)
      if args.count == 0
        @headers
      else
        self.class.new(resource,
          "href" => base_href,
          "name" => name,
          "templated" => templated,
          "params" => params,
          "method" => default_method,
          "headers" => @headers.merge(args[0]))

      end
    end

    ## Unrecognized methods invoke an implicit load of the resource pointed
    ## to by this link.  The method call is then repeated on the returned
    ## resource.
    def method_missing(method, *args) # standard:disable Style/MissingRespondToMissing
      send(default_method || :get).send(method, *args)
    end
  end
end
