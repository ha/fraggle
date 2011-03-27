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

    def send(req, &onre)
      wr = Request.new(req.to_hash)
      wr = cn.send_request(wr)

      req.tag = wr.tag

      wr.valid do |e|
        if req.offset
          req.offset += 1
        end

        if req.limit
          req.limit -= 1
        end

        req.emit(:valid, e)
      end

      wr.done  do
        req.emit(:done)
      end

      wr.error do |e|
        if cn.err?
          reconnect!
          onre.call if onre
        else
          req.emit(:error, e)
        end
      end

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
