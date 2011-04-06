require 'fraggle/client'

module Fraggle

  DEFAULT_URI = "doozer:?" + [
    "ca=127.0.0.1:8046",
    "ca=127.0.0.1:8041",
    "ca=127.0.0.1:8042",
    "ca=127.0.0.1:8043"
  ].join("&")

  def self.connect(uri=nil)
    uri = uri || ENV["DOOZER_URI"] || DEFAULT_URI

    addrs = uri(uri)

    if addrs.length == 0
      raise ArgumentError, "there were no addrs supplied in the uri (#{uri.inspect})"
    end

    addr = addrs.shift
    host, port = addr.split(":")

    cn = EM.connect(host, port, Connection, addr)
    Client.new(cn, addrs)
  end

  def self.uri(u)
    if u =~ /^doozer:\?(.*)$/
      parts = $1.split("&")
      parts.inject([]) do |m, pt|
        k, v = pt.split("=")
        if k == "ca"
          m << v
        end
        m
      end
    else
      raise ArgumentError, "invalid doozer uri"
    end
  end

end
