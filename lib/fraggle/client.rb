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
      req.valid(&blk)

      idemp(req)
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

      idemp(req)
    end

    def getdir(path, rev=nil, offset=nil, &blk)
      req = Request.new
      req.verb   = GETDIR
      req.rev    = rev
      req.path   = path
      req.offset = offset
      req.valid(&blk)

      resend(req)
    end

    def walk(path, rev=nil, offset=nil, &blk)
      req = Request.new
      req.verb   = WALK
      req.rev    = rev
      req.path   = path
      req.offset = offset
      req.valid(&blk)

      resend(req)
    end

    def wait(path, rev=nil, &blk)
      req = Request.new
      req.verb = WAIT
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

    # Sends a request to the server.  Returns the request with a new tag
    # assigned. If `onre` is supplied, it will be invoked when a new connection
    # is established
    def send(req, &onre)
      wr = Request.new(req.to_hash)

      wr.valid do |e|
        log.debug("response: #{e.inspect} for #{req.inspect}")
        req.emit(:valid, e)
      end

      wr.done do
        req.emit(:done)
      end

      wr.error do |e|
        case true
        when e.disconnected?
          # If we haven't already reconnected, do so.
          if cn.err?
            log.error("conn err: #{req.inspect}")
            reconnect!
          end

          if onre
            # Someone else will handle this
            onre.call
          else
            req.emit(:error, e)
          end
        when e.readonly?

          log.error("readonly: #{req.inspect}")

          # Closing the connection triggers a reconnect above.
          cn.close_connection

          if onre
            # Someone else will handle this
            onre.call
          else
            req.emit(:error, Connection::Disconnected)
          end
        else
          log.error("error: #{e.inspect} for #{req.inspect}")
          req.emit(:error, e)
        end

      end

      wr = cn.send_request(wr)
      req.tag = wr.tag
      log.debug("sending: #{req.inspect}")

      req
    end

    def resend(req)
      send(req) do
        req.tag = nil
        log.debug("resending: #{req.inspect}")
        resend(req)
      end
    end

    def idemp(req)
      send(req) do
        if req.rev > 0
          # If we're trying to update a value that isn't missing or that we're
          # not trying to clobber, it's safe to retry.  We can't idempotently
          # update missing values because there may be a race with another
          # client that sets and/or deletes the key during the time between your
          # read and write.
          req.tag = nil
          idemp(req)
        else
          # We can't safely retry the write.  Inform the user.
          req.emit(:error, Connection::Disconnected)
        end
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
      @cn = EM.connect(host, port, Fraggle::Connection, addr)
    end

  end
end
