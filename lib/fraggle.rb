require 'fraggle/errors'
require 'fraggle/logger'
require 'fraggle/snap'
require 'uri'

module Fraggle
  extend Logger

  DefaultUri = "doozer:?"+
    # Default host/port
    "ca=127.0.0.1:8046&"+

    # Default host + test-cluster ports
    "ca=127.0.0.1:8041&"+
    "ca=127.0.0.1:8042&"+
    "ca=127.0.0.1:8043"

  def self.connect(uri=ENV["DOOZER_URI"] || DefaultUri)
    addrs = addrs_for(uri)
    host, port = addrs.first.split(":")
    c = EM.connect(host, port, Client, addrs)
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
