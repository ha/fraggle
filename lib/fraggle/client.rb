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

    attr_reader :cn, :log, :addrs

    def initialize(cn, addrs, log=DefaultLog)
      @cn, @addrs, @log = cn, addrs, log
    end

    def addr
      cn.addr
    end

    def set(path, value, rev, &blk)
      req = Request.new
      req.verb  = SET
      req.rev   = rev
      req.path  = path
      req.value = value

      idemp(req, blk)
    end

    def get(path, rev=nil, &blk)
      req = Request.new
      req.verb = GET
      req.rev  = rev
      req.path = path

      resend(req, blk)
    end

    def del(path, rev, &blk)
      req = Request.new
      req.verb = DEL
      req.rev  = rev
      req.path = path

      idemp(req, blk)
    end

    def getdir(path, rev=nil, offset=nil, &blk)
      req = Request.new
      req.verb   = GETDIR
      req.rev    = rev
      req.path   = path
      req.offset = offset

      resend(req, blk)
    end

    def walk(path, rev=nil, offset=nil, &blk)
      req = Request.new
      req.verb   = WALK
      req.rev    = rev
      req.path   = path
      req.offset = offset

      resend(req, blk)
    end

    def wait(path, rev=nil, &blk)
      req = Request.new
      req.verb = WAIT
      req.rev  = rev
      req.path = path

      resend(req, blk)
    end

    def rev(&blk)
      req = Request.new
      req.verb = REV

      resend(req, blk)
    end

    def stat(path, rev=nil, &blk)
      req = Request.new
      req.rev  = rev
      req.verb = STAT
      req.path = path

      resend(req, blk)
    end

    # Sends a request to the server.  Returns the request with a new tag
    # assigned.
    def send(req, blk)
      cb = Proc.new do |e|
        log.debug("response: #{e.inspect} for #{req.inspect}")

        case true
        when e.disconnected?
          # If we haven't already reconnected, do so.
          if cn.err?
            log.error("conn err: #{req.inspect}")
            reconnect!
          end
          blk.call(e)
        when e.readonly?
          log.error("readonly: #{req.inspect}")

          # Closing the connection triggers a reconnect above.
          cn.close_connection

          blk.call(Connection::Disconnected)
        when e.ok?
          blk.call(e)
        else
          log.error("error: #{e.inspect} for #{req.inspect}")
          blk.call(e)
        end

      end
      req.valid(&cb)

      log.debug("sending: #{req.inspect}")
      cn.send_request(req)
    end

    def resend(req, blk)
      cb = Proc.new do |e|
        if e.disconnected?
          req.tag = nil
          log.debug("resending: #{req.inspect}")
          resend(req, blk)
        else
          blk.call(e)
        end
      end

      send(req, cb)
    end

    def idemp(req, blk)
      cb = Proc.new do |e|
        if e.disconnected? && req.rev > 0
          # If we're trying to update a value that isn't missing or that we're
          # not trying to clobber, it's safe to retry.  We can't idempotently
          # update missing values because there may be a race with another
          # client that sets and/or deletes the key during the time between your
          # read and write.
          req.tag = nil
          idemp(req, blk)
          next
        end

        blk.call(e)
      end

      send(req, cb)
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
      @cn = EM.connect(host, port, Fraggle::Connection, addr)
    end

  end
end
