require 'eventmachine'
require 'fraggle/connection'

module Fraggle
  class Client
    include Request::Verb

    MaxInt64 = 1<<63 - 1

    attr_reader :cn, :addrs

    def initialize(cn, addrs)
      @cn, @addrs = cn, addrs
      @attempt = Proc.new {|_| true }
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

    def _getdir(rev, path, offset, &blk)
      req = Request.new
      req.verb   = GETDIR
      req.rev    = rev
      req.path   = path
      req.offset = offset

      resend(req, &blk)
    end

    def _walk(rev, path, offset, &blk)
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

      resend(req) do |v, _|
        blk.call(v.rev)
      end
    end

    def stat(rev, path, &blk)
      req = Request.new
      req.rev  = rev
      req.verb = STAT
      req.path = path

      resend(req, &blk)
    end

    def access(secret, &blk)
      req = Request.new
      req.verb  = ACCESS
      req.value = secret

      resend(req, &blk)
    end

    def watch(rev, path, &blk)
      wait(rev, path) do |e, err|
        blk.call(e, err)
        if ! err
          watch(e.rev+1, path, &blk)
        end
      end
    end

    def getdir(rev, path, off=0, lim=MaxInt64, ents=[], &blk)
      all(:_getdir, rev, path, off, lim, ents, &blk)
    end

    def walk(rev, path, off=0, lim=MaxInt64, ents=[], &blk)
      all(:_walk, rev, path, off, lim, ents, &blk)
    end

    def all(m, rev, path, off, lim, ents=[], &blk)
      # We're decrementing lim as we go, so we need to return
      # the accumulated values
      if lim == 0
        cn.next_tick { blk.call(ents, nil) }
        return
      end

      __send__(m, rev, path, off) do |e, err|
        case err && err.code
        when nil
          all(m, rev, path, off+1, lim-1, ents << e, &blk)
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
      cb = Proc.new do |e, err|
        case err
        when Connection::DisconnectedError
          if cn.err?
            reconnect!
          end
        end
        blk.call(e, err)
      end

      cn.send_request(req, cb)
    end

    def resend(req, &blk)
      send(req) do |e, err|
        case err
        when Connection::DisconnectedError
          req.tag = nil
          resend(req, &blk)
        else
          blk.call(e, err)
        end
      end
    end

    def idemp(req, &blk)
      send(req) do |e, err|
        case err
        when Connection::DisconnectedError
          # If we're trying to update a value that isn't missing or that we're
          # not trying to clobber, it's safe to retry.  We can't idempotently
          # update missing values because there may be a race with another
          # client that sets and/or deletes the key during the time between your
          # read and write.
          if (req.rev || 0) > 0
            req.tag = nil
            idemp(req, &blk)
          else
            blk.call(e, err)
          end
        else
          blk.call(e, err)
        end
      end
    end

    ##
    # Setting `blk` will cause a client to call it before attempting to reconnect.
    # `blk` is called with one parameter `addr`, which is the address that will be
    # for reconnect.
    def attempt(&blk)
      @attempt = blk
    end

    def reconnect!
      addr = @addrs.slice(rand(@addrs.length))
      if @attempt.call(addr)
        reconnect(addr)
      end
    end

    def reconnect(addr)
      host, port = addr.split(":")
      @cn = EM.connect(host, port, Fraggle::Connection, addr)
    end

  end
end
