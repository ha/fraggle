require 'eventmachine'
require 'fraggle/connection'

module Fraggle
  class Client

    class NoMoreAddrs < StandardError
    end

    attr_reader :cn

    def initialize(cn, addrs)
      @cn, @addrs = cn, addrs
    end

    def send(req, &onerr)
      wr = Request.new(req.to_hash)
      wr = cn.send_request(wr)

      wr.valid {|e| req.emit(:valid, e) }
      wr.done  {    req.emit(:done) }
      wr.error do |e|
        if cn.err?
          reconnect!
          onerr.call(e) if onerr
        else
          req.emit(:error, e)
        end
      end


      req.tag = wr.tag
      req
    end

    def resend(req)
      send(req) do
        req.tag = nil
        resend(req)
      end
    end

    def reconnect!
      if addr = @addrs.shift
        host, port = addr.split(":")
        reconnect(host, port)
      else
        raise NoMoreAddrs
      end
    end

    def reconnect(host, port)
      @cn = EM.connect(host, port, Fraggle::Connection, @addrs)
    end

  end
end
