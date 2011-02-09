require 'fraggle/snap'
require 'uri'

module Fraggle

  def self.connect(uri, *args)
    params = uri.gsub(/^doozer:\?/, '').split("&")
    addrs  = []

    params.each do |param|
      k, v = param.split("=")
      if k == "ca" && v =~ /^[\d.]+:\d+$/
        addrs << v
      end
    end

    if addrs.empty?
      fail "The URI (#{uri}) does not contain valid addresses"
    end

    host, port = addrs.first.split(":")
    c = EM.connect(host, port, Client, addrs, *args)
    Snap.new(0, c)
  end

end
