require "uri"

class HyperResource
  ## HyperResource::Configuration is a class which implements a hostmask-
  ## scoped set of configurations.  Key/value pairs are stored under hostmasks
  ## like 'api.example.com:8080', 'api.example.com', '*.example.com', or '*'.
  ## Values are retrieved using a hostname and a key, preferring more specific
  ## hostmasks when more than one matching hostmask and key are present.
  ##
  ## HyperResource users are not expected to use this class directly.
  class Configuration
    ## Creates a new HyperResource::Configuration, with the given initial
    ## internal state if provided.
    def initialize(cfg = {})
      @cfg = cfg
      @cfg["*"] ||= {}
    end

    ## Returns a deep copy of this object.
    def clone
      self.class.new.send(:initialize_copy, self)
    end

    ## Merges a given Configuration with this one.  Deep-merges config
    ## attributes correctly.
    def merge(new)
      merged_cfg = {}
      new_cfg = new.send(:cfg)

      (new_cfg.keys | cfg.keys).each do |mask|
        new_cfg_attrs = new_cfg[mask] || {}
        cfg_attrs = cfg[mask] || {}
        merged_cfg[mask] = {}

        ## Do a hash merge when it makes sense, except when it doesn't.
        (new_cfg_attrs.keys | cfg_attrs.keys).each do |attr|
          merged_cfg[mask][attr] = if !%w[namespace adapter].include?(attr) &&
              (!cfg_attrs[attr] || cfg_attrs[attr].is_a?(Hash)) &&
              (!new_cfg_attrs[attr] || new_cfg_attrs[attr].is_a?(Hash))
            (cfg_attrs[attr] || {}).merge(new_cfg_attrs[attr] || {})
          else
            new_cfg_attrs[attr] || cfg_attrs[attr]
          end
        end
      end
      self.class.new(merged_cfg)
    end

    ## Applies a given Configuration on top of this one.
    def merge!(new)
      initialize_copy(merge(new))
    end

    ## Applies a given Hash of configurations on top of this one.
    def config(hash)
      merge!(self.class.new(hash))
    end

    ## Returns this object as a Hash.
    def as_hash
      clone.send(:cfg)
    end

    ## Returns the value for a particular hostmask and key, or nil if not
    ## present.
    def get(mask, key)
      cfg[mask] ||= {}
      cfg[mask][key.to_s]
    end

    ## Sets a key and value pair for the given hostmask.
    def set(mask, key, value)
      cfg[mask] ||= {}
      cfg[mask][key.to_s] = value
    end

    ## Returns the best matching value for the given URL and key, or nil
    ## otherwise.
    def get_for_url(url, key)
      subconfig_for_url(url)[key.to_s]
    end

    ## Sets a key and value pair, using the given URL as the basis of the
    ## hostmask.  Path, query, and fragment are ignored.
    def set_for_url(url, key, value)
      set(url ? mask_for_url(url) : "*", key, value)
    end

    ## Returns hostmasks from our config which match the given url, sorted
    ## best match first.
    def matching_masks_for_url(url)
      return ["*"] if cfg.keys.count == 1
      url_parts = parse_url(url.to_s)
      scores = {}
      cfg.keys.each do |mask|
        score = match_mask(parse_url(mask), url_parts)
        scores[mask] = score if score
      end
      scores.keys.sort_by { |k| [-scores[k], -k.length] }
    end

    private

    attr_reader :cfg

    ## Performs a two-level-deep copy of old @cfg.
    def initialize_copy(old)
      old.send(:cfg).each do |mask, old_subcfg|
        new_subcfg = {}
        old_subcfg.each do |key, value|
          if value.is_a?(Array) || value.is_a?(Hash)
            value = value.clone
          end
          new_subcfg[key] = value
        end
        @cfg[mask] = new_subcfg
      end
      self
    end

    ## Returns a merged subconfig consisting of all matching hostmask
    ## subconfigs, giving priority to more specific hostmasks.
    def subconfig_for_url(url)
      matching_masks_for_url(url).inject({}) do |subcfg, mask|
        (cfg[mask] || {}).merge(subcfg)
      end
    end

    ## Adapted from FuzzyURL.url_to_hash in fuzzyurl 0.2.2
    ## (https://github.com/gamache/fuzzyurl), keeping only protocol, host, and port.
    URL_PATTERN = %r{\A(?:(\*|[a-z][a-z0-9+.-]*)://)?(?:[^@/]*@)?([a-z0-9.*-]*)(?::(\*|\d+))?}i

    DEFAULT_PORTS = {"http" => "80", "https" => "443"}

    ## Returns the protocol, host, and port of a URL or hostmask.
    def parse_url(url)
      m = url.match(URL_PATTERN)
      {protocol: m[1]&.downcase, host: m[2].downcase, port: m[3]}
    end

    ## Returns the hostmask for a URL, without path, query, or fragment.
    def mask_for_url(url)
      parts = parse_url(url.to_s)
      mask = parts[:host]
      mask = "#{parts[:protocol]}://#{mask}" if parts[:protocol]
      mask = "#{mask}:#{parts[:port]}" if parts[:port]
      mask
    end

    ## Returns nil if the mask does not match the url, or a score which is
    ## higher for more specific matches.
    def match_mask(mask, url)
      host_score = match_hosts(mask[:host], url[:host])
      port_score = match_protocols_and_ports(mask, url)
      host_score + port_score if host_score && port_score
    end

    ## Returns nil for no match, 0 for a wildcard match, or 1 for an exact
    ## match.
    def match_hosts(mask, host)
      mask_pieces = mask.split(".").reverse
      host_pieces = host.split(".").reverse
      return 1 if !mask.empty? && mask_pieces == host_pieces
      return nil if mask_pieces.count > host_pieces.count
      host_pieces.each_with_index do |piece, i|
        return 0 if mask_pieces[i] == "*"
        return nil if mask_pieces[i] != piece
      end
      0
    end

    ## Returns nil for no match, or 0-2 for the number of exact matches.
    ## Protocol defaults to https, and a port matches its protocol's default.
    def match_protocols_and_ports(mask, url)
      wildcards = 0
      protocol = url[:protocol] || "https"
      if mask[:protocol] && mask[:protocol] != "*"
        return nil if mask[:protocol] != protocol
      else
        wildcards += 1
      end

      if !mask[:port] || mask[:port] == "*"
        wildcards += 1
      elsif !url[:port] && DEFAULT_PORTS[protocol] == mask[:port]
        wildcards += 1
      elsif mask[:port] != url[:port]
        return nil
      end

      2 - wildcards
    end
  end
end
