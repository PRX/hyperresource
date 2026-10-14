require 'test_helper'


describe HyperResource::Configuration do

  describe '#get and #set' do
    it 'works' do
      cfg = HyperResource::Configuration.new
      cfg.set('test', 'a', 'b')
      _(cfg.get('test', 'a')).must_equal 'b'
      _(cfg.get('test2', 'a')).must_be_nil
      _(cfg.get('test', 'b')).must_be_nil
    end
  end

  describe '#clone' do
    it 'works' do
      cfg = HyperResource::Configuration.new
      b = 'b'
      cfg.set('test', 'a', b)
      newcfg = cfg.clone

      _(newcfg.get('test', 'a')).must_equal 'b'

      ## No shared structure at first level
      newcfg.set('test', 'a', 'c')
      _(cfg.get('test', 'a')).must_equal 'b'
    end
  end

  describe '#merge' do
    it 'merges' do
      cfg1 = HyperResource::Configuration.new
      cfg1.set('test1', 'a', 'b')
      cfg1.set('test2', 'c', 'd')

      cfg2 = HyperResource::Configuration.new
      cfg2.set('test1', 'a', 'e')
      cfg2.set('test3', 'f', 'g')

      merged = cfg1.merge(cfg2)
      _(merged.get('test1', 'a')).must_equal 'e'
      _(merged.get('test2', 'c')).must_equal 'd'
      _(merged.get('test3', 'f')).must_equal 'g'
    end
  end

  describe '#merge!' do
    it 'mergebangs' do
      cfg1 = HyperResource::Configuration.new
      cfg1.set('test1', 'a', 'b')
      cfg1.set('test2', 'c', 'd')

      cfg2 = HyperResource::Configuration.new
      cfg2.set('test1', 'a', 'e')
      cfg2.set('test3', 'f', 'g')

      cfg1.merge!(cfg2)
      _(cfg1.get('test1', 'a')).must_equal 'e'
      _(cfg1.get('test2', 'c')).must_equal 'd'
      _(cfg1.get('test3', 'f')).must_equal 'g'
    end
  end

  describe '#as_hash' do
    it 'works' do
      cfg = HyperResource::Configuration.new
      cfg.set('test1', 'a', {'b' => 1})
      cfg.set('test2', 'c', 'd')

      hash = cfg.as_hash
      _(hash['test1']['a']).must_equal({'b' => 1})
      _(hash['test2']['c']).must_equal('d')

      hash['test1']['a']['b'] = 2
      _(cfg.get('test1', 'a')['b']).must_equal 1
    end
  end

  describe '#config' do
    it 'works' do
      cfg = HyperResource::Configuration.new
      cfg.set('test1', 'y', 'z')
      cfg.config(
        '*'           => {'a' => 'b'},
        'example.com' => {'a' => 'c', 'd' => 'e'}
      )

      _(cfg.send(:cfg)).must_equal(
        'test1'       => {'y' => 'z'},
        '*'           => {'a' => 'b'},
        'example.com' => {'a' => 'c', 'd' => 'e'}
      )
    end
  end

  describe '#get_for_url' do
    it 'returns exact matches' do
      cfg = HyperResource::Configuration.new
      cfg.set('example.com', 'a', 'b')

      _(cfg.get_for_url('http://example.com', 'a')).must_equal 'b'
      _(cfg.get_for_url('https://example.com/v1/omg', 'a')).must_equal 'b'
      _(cfg.get_for_url('http://example.com?utm_source=friendster', 'a')).must_equal 'b'
      _(cfg.get_for_url('http://example.com', 'a')).must_equal 'b'

      _(cfg.get_for_url('http://example2.com', 'a')).must_be_nil
      _(cfg.get_for_url('http://www.example.com', 'a')).must_be_nil
      _(cfg.get_for_url('http://example.com.au', 'a')).must_be_nil
    end

    it 'returns subdomain wildcard matches' do
      cfg = HyperResource::Configuration.new
      cfg.set('*.example.com', 'a', 'b')

      _(cfg.get_for_url('http://www.example.com', 'a')).must_equal 'b'
      _(cfg.get_for_url('https://www.example.com/INDEX.HTM', 'a')).must_equal 'b'
      _(cfg.get_for_url('http://www4.us.example.com', 'a')).must_equal 'b'

      _(cfg.get_for_url('http://example.com', 'a')).must_be_nil
    end

    it 'matches protocols and ports' do
      cfg = HyperResource::Configuration.new
      cfg.set('https://example.com', 'a', 'https')
      cfg.set('example.com:8080', 'b', '8080')
      cfg.set('example.com:80', 'c', '80')
      cfg.set('example.com:*', 'd', 'any port')

      _(cfg.get_for_url('https://example.com/x', 'a')).must_equal 'https'
      _(cfg.get_for_url('http://example.com/x', 'a')).must_be_nil
      _(cfg.get_for_url('http://example.com:8080', 'b')).must_equal '8080'
      _(cfg.get_for_url('http://example.com:9090', 'b')).must_be_nil
      _(cfg.get_for_url('http://example.com', 'b')).must_be_nil
      _(cfg.get_for_url('http://example.com', 'c')).must_equal '80'
      _(cfg.get_for_url('https://example.com', 'c')).must_be_nil
      _(cfg.get_for_url('http://example.com:9090', 'd')).must_equal 'any port'
    end

    it 'ignores case and credentials' do
      cfg = HyperResource::Configuration.new
      cfg.set('EXAMPLE.com', 'a', 'b')
      cfg.set('user@example.com', 'c', 'd')

      _(cfg.get_for_url('http://user:pw@Example.COM/', 'a')).must_equal 'b'
      _(cfg.get_for_url('http://example.com/', 'c')).must_equal 'd'
    end
  end

  describe '#set_for_url' do
    it 'works' do
      cfg = HyperResource::Configuration.new
      cfg.set_for_url('http://example.com', 'a', 'b')
      _(cfg.get_for_url('example.com', 'a')).must_equal 'b'
      _(cfg.get('http://example.com', 'a')).must_equal 'b'
    end

    it 'keeps protocol and port, and drops path, query, and credentials' do
      cfg = HyperResource::Configuration.new
      cfg.set_for_url('https://user:pw@example.com:8443/v1?q=1#f', 'a', 'b')
      _(cfg.get('https://example.com:8443', 'a')).must_equal 'b'
    end

    it 'uses the wildcard mask without a url' do
      cfg = HyperResource::Configuration.new
      cfg.set_for_url(nil, 'a', 'b')
      _(cfg.get('*', 'a')).must_equal 'b'
    end
  end

  describe '#get_possible_masks_for_host' do
    it 'generates correct hostmasks' do
      cfg = HyperResource::Configuration.new
      masks = cfg.send(:get_possible_masks_for_host, 'www4.us.example.com')
      _(masks).must_equal ["www4.us.example.com:80",
                        "www4.us.example.com",
                        "*.us.example.com",
                        "*.example.com",
                        "*.com",
                        "*"]
    end
  end

  describe '#matching_masks_for_url' do
    it 'returns existing hostmasks' do
      cfg = HyperResource::Configuration.new
      cfg.set('www4.us.example.com:12345', 'a', 'b')
      cfg.set('www4.us.example.com', 'a', 'b')
      cfg.set('*.example.com', 'a', 'b')
      cfg.set('*', 'a', 'b')
      cfg.set('something', 'y', 'z')
      masks = cfg.send(:matching_masks_for_url, 'http://www4.us.example.com:12345')
      _(masks).must_equal ["www4.us.example.com:12345",
                        "www4.us.example.com",
                        "*.example.com",
                        "*"]
    end
  end

  describe '#subconfig_for_url' do
    it 'merges hostmask configs correctly' do
      cfg = HyperResource::Configuration.new
      cfg.set('www4.us.example.com', 'a', 'b')
      cfg.set('*.example.com', 'd', 'e')
      cfg.set('*', 'a', 'c')

      subconfig = cfg.send(:subconfig_for_url, 'http://www4.us.example.com')
      _(subconfig['a']).must_equal 'b'
      _(subconfig['d']).must_equal 'e'
    end
  end

end

