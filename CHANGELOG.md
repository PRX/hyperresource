# Changelog

## 1.0.0

First release as `prx_hyperresource`, PRX's fork of
[hyperresource](https://github.com/gamache/hyperresource) 0.9.4. The library
is still loaded as `HyperResource`, and `require "hyperresource"` still works.

- Support Ruby 4: require `cgi`, which is no longer in Ruby's stdlib.
- Match URL masks without the `fuzzyurl` gem, but with similar logic.
- Treat URLs without a protocol as `https` (port 443) when matching masks.
- Support Faraday 2 basic auth, using the authorization middleware.
- Don't share cached connections between resources with different `faraday_options`.
- Default to `application/json` unless a Content-Type is configured.
- Prefer headers from more specific masks over `*`.
- Require Ruby 3.3 or later.
- Remove `HyperResource::VERSION_DATE` and the gemspec `date`.
