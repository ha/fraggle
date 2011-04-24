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
      monitor_addrs
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

    def monitor_addrs
      log.debug("monitor addrs")
      rev do |v|
        walk("/ctl/cal/*", v.rev) do |e|
          get("/ctl/node/#{e.value}/addr", v.rev) do |a|
            if a.value != ""
              add_addr(a.value)
            end
          end
        end.done do
          watch("/ctl/cal/*", v.rev+1) do |e|
            if e.value == ""
              ## Look to see what it was before
              get(e.path, e.rev-1) do |b|
                if b.rev > 0
                  # The node was cleared.  Delete it from the list of addrs.
                  log.debug("del addr: #{addr}")
                  @addrs.delete(b.value)
                end
              end
            else
              add_addr(e.value)
            end
          end
        end
      end
    end

    def add_addr(s)
      return if s == self.addr
      return if @addrs.include?(s)
      log.debug("add addr: #{s}")
      @addrs << addr
    end

    # Sends a request to the server.  Returns the request with a new tag
    # assigned. If `onre` is supplied, it will be invoked when a new connection
    # is established
    def send(req, &onre)
      wr = Request.new(req.to_hash)

      wr.valid do |e|
        log.debug("response: #{e.inspect} for #{req.inspect}")

        if req.offset
          req.offset += 1
        end

        if req.limit
          req.limit -= 1
        end

        if (req.rev || 0) < (e.rev || 0)
          log.debug("updating rev: to #{e.rev} - #{req.inspect}")
          req.rev = e.rev
        end

        req.emit(:valid, e)
      end

      wr.done do
        req.emit(:done)
      end

      wr.error do |e|
        case true
        when e.disconnected?
          p [:disconnected]
          # If we haven't already reconnected, do so.
          if cn.err?
            p :reconnecting!
            log.error("conn err: #{req.inspect}")
            reconnect!
          end

          if onre
            # Someone else will handle this
            onre.call
          else
            req.emit(:error, e)
          end
        when e.redirect?
          p [:redirect]

          log.error("redirect: #{req.inspect}")

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
      @cn = EM.connect(host, port, Fraggle::Connection, @addrs)
    end

  end
end
