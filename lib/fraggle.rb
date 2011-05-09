require 'fraggle/client'

module Fraggle
  include Response::Err

  Clobber = Client::MaxInt64

  DEFAULT_URI = "doozer:?" + [
    "ca=127.0.0.1:8046",
    "ca=127.0.0.1:8041",
    "ca=127.0.0.1:8042",
    "ca=127.0.0.1:8043"
  ].join("&")

  def self.connect(uri=nil, &blk)
    uri = uri || ENV["DOOZER_URI"] || DEFAULT_URI

    addrs, sk = uri(uri)

    if addrs.length == 0
      raise ArgumentError, "there were no addrs supplied in the uri (#{uri.inspect})"
    end

    addr = addrs.shift
    host, port = addr.split(":")

    cn = EM.connect(host, port, Connection, addr)
    c  = Client.new(cn, addrs)
    c.access(sk) do |_, err|
      if err
        blk.call(nil, err)
      else
        blk.call(c, nil)
      end
    end
  end

  def self.uri(u)
    addrs, sk = [], ""

    if u =~ /^doozer:\?(.*)$/
      parts = $1.split("&")
      parts.each do |pt|
        k, v = pt.split("=")
        case k
        when "ca"
          addrs << v
        when "sk"
          sk = v
        end
      end
    else
      raise ArgumentError, "invalid doozer uri"
    end

    [addrs, sk]
  end

end
