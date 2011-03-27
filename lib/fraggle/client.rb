require 'eventmachine'
require 'fraggle/connection'

module Fraggle
  class Client
    include Request::Verb

    class NoMoreAddrs < StandardError
    end

    attr_reader :cn

    def initialize(cn, addrs)
      @cn, @addrs = cn, addrs
    end

    def set(rev, path, value, &blk)
      req = Request.new
      req.verb  = SET
      req.rev   = rev
      req.path  = path
      req.value = value
      req.valid(&blk)

      send(req)
    end

    def get(rev, path, &blk)
      req = Request.new
      req.verb = GET
      req.rev  = rev
      req.path = path
      req.valid(&blk)

      send(req)
    end

    def del(rev, path, &blk)
      req = Request.new
      req.verb = DEL
      req.rev  = rev
      req.path = path
      req.valid(&blk)

      send(req)
    end

    def getdir(rev, path, offset=nil, limit=nil, &blk)
      req = Request.new
      req.verb = GETDIR
      req.rev  = rev
      req.path = path
      req.offset = offset
      req.limit  = limit
      req.valid(&blk)

      send(req)
    end

    def rev(&blk)
      req = Request.new
      req.verb = REV
      req.valid(&blk)

      send(req)
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

        if (req.rev || 0) < (e.rev || 0)
          req.rev = e.rev
        end

        req.emit(:valid, e)
      end

      wr.done  do
        req.emit(:done)
      end

      wr.error do |e|
        case true
        when cn.err? || e.redirect?
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
        reconnect(addr)
      else
        raise NoMoreAddrs
      end
    end

    def reconnect(addr)
      host, port = addr.split(":")
      @cn = EM.connect(host, port, Fraggle::Connection, @addrs)
    end

  end
end
