require 'eventmachine'
require 'fraggle/connection'
require 'logger'

module Fraggle
  class Client
    include Request::Verb

    class NoMoreAddrs < StandardError
    end

    DefaultLog = Logger.new(STDERR)
    DefaultLog.level = Logger::UNKNOWN

    Disconnected = Request.new(:disconnected => true)

    attr_reader :cn, :log

    def initialize(cn, addrs, log=DefaultLog)
      @cn, @addrs, @log = cn, addrs, log
    end

    def set(path, value, rev, &blk)
      req = Request.new
      req.verb  = SET
      req.rev   = rev
      req.path  = path
      req.value = value
      req.valid(&blk)

      send(req)
    end

    def get(path, rev=nil, &blk)
      req = Request.new
      req.verb = GET
      req.rev  = rev
      req.path = path
      req.valid(&blk)

      resend(req)
    end

    def del(path, rev, &blk)
      req = Request.new
      req.verb = DEL
      req.rev  = rev
      req.path = path
      req.valid(&blk)

      send(req)
    end

    def getdir(path, rev=nil, offset=nil, limit=nil, &blk)
      req = Request.new
      req.verb = GETDIR
      req.rev  = rev
      req.path = path

      # To reliably pick-up where we left off in the event of a disconnect, we
      # must default the offset to zero.  This is best done here and not in the
      # param declaration because the user could override it to nil there.
      req.offset = offset || 0
      req.limit  = limit
      req.valid(&blk)

      resend(req)
    end

    def walk(path, rev=nil, offset=nil, limit=nil, &blk)
      req = Request.new
      req.verb = WALK
      req.rev  = rev
      req.path = path

      # To reliably pick-up where we left off in the event of a disconnect, we
      # must default the offset to zero.  This is best done here and not in the
      # param declaration because the user could override it to nil there.
      req.offset = offset || 0
      req.limit  = limit
      req.valid(&blk)

      resend(req)
    end

    def watch(path, rev=nil, &blk)
      req = Request.new
      req.verb = WATCH
      req.rev  = rev
      req.path = path
      req.valid(&blk)

      resend(req)
    end

    def rev(&blk)
      req = Request.new
      req.verb = REV
      req.valid(&blk)

      resend(req)
    end

    def stat(path, rev=nil, &blk)
      req = Request.new
      req.rev  = rev
      req.verb = STAT
      req.path = path
      req.valid(&blk)

      resend(req)
    end

    def send(req, &onre)
      wr = Request.new(req.to_hash)
      wr = cn.send_request(wr)

      req.tag = wr.tag

      log.debug("sending: #{req.inspect}")

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

      wr.done do
        req.emit(:done)
      end

      wr.error do |e|
        case true
        when cn.err? || e.redirect?
          log.error("conn error: #{req.inspect}")
          reconnect!
          onre.call if onre
        else
          log.error("resp error: #{req.inspect}")
          req.emit(:error, e)
        end
      end

      req
    end

    def resend(req)
      send(req) do
        req.tag = nil
        log.debug("resending: #{req.inspect}")
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
      log.warn("reconnecting to #{addr}")
      host, port = addr.split(":")
      @cn = EM.connect(host, port, Fraggle::Connection, @addrs)
    end

  end
end
