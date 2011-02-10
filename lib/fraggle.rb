require 'fraggle/errors'
require 'fraggle/logger'
require 'fraggle/snap'
require 'uri'

module Fraggle
  extend Logger

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

  def self.addrs_for(uri)
    params = uri.gsub(/^doozer:\?/, '').split("&")
    addrs  = []

    params.each do |param|
      k, v = param.split("=")
      if k == "ca"
        # Perform a liberal validation to weed out most mistakes
        if v =~ /^[\d\w\-.]+:\d+$/
          addrs << v
        else
          warn "invalid addr (#{v}) in #{uri}"
        end
      end
    end

    if addrs.empty?
      raise NoAddrs
    end

    addrs
  end

end
