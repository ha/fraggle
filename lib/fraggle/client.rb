require 'eventmachine'
require 'fraggle/connection'

module Fraggle
  class Client
    include Request::Verb

    MaxInt64 = 1<<63 - 1

    class NoMoreAddrs < StandardError
    end

    attr_reader :cn, :addrs

    def initialize(cn, addrs)
      @cn, @addrs = cn, addrs
    end

    def addr
      cn.addr
    end

    def set(rev, path, value, &blk)
      req = Request.new
      req.verb  = SET
      req.rev   = rev
      req.path  = path
      req.value = value

      idemp(req, &blk)
    end

    def get(rev, path, &blk)
      req = Request.new
      req.verb = GET
      req.rev  = rev
      req.path = path

      resend(req, &blk)
    end

    def del(rev, path, &blk)
      req = Request.new
      req.verb = DEL
      req.rev  = rev
      req.path = path

      idemp(req, &blk)
    end

    def getdir(rev, path, offset, &blk)
      req = Request.new
      req.verb   = GETDIR
      req.rev    = rev
      req.path   = path
      req.offset = offset

      resend(req, &blk)
    end

    def walk(rev, path, offset, &blk)
      req = Request.new
      req.verb   = WALK
      req.rev    = rev
      req.path   = path
      req.offset = offset

      resend(req, &blk)
    end

    def wait(rev, path, &blk)
      req = Request.new
      req.verb = WAIT
      req.rev  = rev
      req.path = path

      resend(req, &blk)
    end

    def rev(&blk)
      req = Request.new
      req.verb = REV

      resend(req, &blk)
    end

    def stat(rev, path, &blk)
      req = Request.new
      req.rev  = rev
      req.verb = STAT
      req.path = path

      resend(req, &blk)
    end

    def watch(rev, path, &blk)
      wait(rev, path, rev) do |e|
        blk.call(e)
        if e.ok?
          watch(rev, path, e.rev+1, &blk)
        end
      end
    end

    def getdir_all(rev, path, off=0, lim=MaxInt64, ents=[], &blk)
      all(:getdir, rev, path, off, lim, ents, &blk)
    end

    def walk_all(rev, path, off=0, lim=MaxInt64, ents=[], &blk)
      all(:walk, rev, path, off, lim, ents, &blk)
    end

    def all(m, rev, path, off, lim, ents=[], &blk)
      if lim == 0
        cn.next_tick { blk.call([], nil) }
        return
      end

      __send__(m, rev, path, off) do |e|
        case e.err_code
        when nil
          ents << e
          all(m, rev, path, off+1, lim-1, ents, &blk)
        when Fraggle::Response::Err::RANGE
          blk.call(ents, nil)
        else
          blk.call(nil, e)
        end
      end
    end

    # Sends a request to the server.  Returns the request with a new tag
    # assigned.
    def send(req, &blk)
      cb = Proc.new do |e|
        if e.disconnected? && cn.err?
          reconnect!
        end

        blk.call(e)
      end

      cn.send_request(req, cb)
    end

    def resend(req, &blk)
      cb = Proc.new do |e|
        if e.disconnected?
          req.tag = nil
          resend(req, &blk)
        else
          blk.call(e)
        end
      end

      send(req, &cb)
    end

    def idemp(req, &blk)
      cb = Proc.new do |e|
        if e.disconnected? && req.rev > 0
          # If we're trying to update a value that isn't missing or that we're
          # not trying to clobber, it's safe to retry.  We can't idempotently
          # update missing values because there may be a race with another
          # client that sets and/or deletes the key during the time between your
          # read and write.
          req.tag = nil
          idemp(req, &blk)
          next
        end

        blk.call(e)
      end

      send(req, &cb)
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
      @cn = EM.connect(host, port, Fraggle::Connection, addr)
    end

  end
end
