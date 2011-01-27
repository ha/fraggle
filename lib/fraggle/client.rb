require 'fraggle/meta'
require 'fraggle/protocol'
require 'fraggle/request'
require 'fraggle/response'

module Fraggle

  module Client
    include Protocol

    class Error < StandardError ; end


    MinTag = 0
    MaxTag = (1<<32)


    def initialize
      @cbx = {}
    end

    def receive_response(res)
      if res.err_code
        if req = @cbx.delete(res.tag)
          req.emit(:error, res)
          return
        end
      end

      if (res.flags & Response::Flag::VALID) > 0
        if req = @cbx[res.tag]
          req.emit(:valid, res)
        end
      end

      if (res.flags & Response::Flag::DONE) > 0
        if req = @cbx.delete(res.tag)
          req.emit(:done)
        end
      end
    end

    def checkin(path, cas, &blk)
      req = Request.new
      req.verb  = Request::Verb::CHECKIN
      req.path  = path
      req.cas   = cas

      send(req, &blk)
    end

    def get(sid, path, &blk)
      req = Request.new
      req.verb = Request::Verb::GET
      req.id   = sid if sid != 0 # wire optimization
      req.path = path

      send(req, &blk)
    end

    def set(path, value, cas, &blk)
      req = Request.new
      req.verb  = Request::Verb::SET
      req.path  = path
      req.value = value
      req.cas   = cas

      send(req, &blk)
    end

    def del(path, cas, &blk)
      req = Request.new
      req.verb  = Request::Verb::DEL
      req.path  = path
      req.cas   = cas

      send(req, &blk)
    end

    def walk(sid, glob, &blk)
      req = Request.new
      req.verb = Request::Verb::WALK
      req.id   = sid if sid != 0 # wire optimization
      req.path = glob

      cancelable(send(req, &blk))
    end

    def watch(glob, &blk)
      req = Request.new
      req.verb = Request::Verb::WATCH
      req.path = glob

      cancelable(send(req, &blk))
    end

    def snap(&blk)
      req = Request.new
      req.verb = Request::Verb::SNAP

      send(req, &blk)
    end

    def delsnap(sid, &blk)
      req = Request.new
      req.verb = Request::Verb::DELSNAP
      req.id = sid

      send(req, &blk)
    end

    def noop(&blk)
      req = Request.new
      req.verb = Request::Verb::NOOP

      send(req, &blk)
    end

    # Be careful with this.  It is recommended you use #cancel on the Request
    # returned to ensure you don't run into a race-condition where you cancel an
    # operation you may have thought was something else.
    def __cancel__(what, &blk)
      req = Request.new
      req.verb = Request::Verb::CANCEL
      req.id = what.tag

      # Hold on to the tag as unavaiable for reuse until the cancel succeeds.
      @cbx[what.tag] = nil

      send(req) do |res|
        # Do not send any more responses from the server to this request.
        @cbx.delete(what.tag)
        blk.call(res) if blk
      end
    end

    def send(req, &blk)
      tag = MinTag

      while @cbx.has_key?(tag)
        tag += 1
        if tag > MaxTag
          tag = MinTag
        end
      end

      req.tag = tag

      if blk
        req.valid(&blk)
      end

      # Setup a default error handler that gives useful information
      req.error do |e|
        raise Error.new("'%s' for: %s" % [e.err_detail, req.inspect])
      end

      @cbx[req.tag] = req
      send_request(req)

      req
    end

    def cancelable(req)
      c   = self
      can = true

      req.metadef :cancel do
        if can
          can = false
          c.__cancel__(self)
        end
      end

      req.metadef :canceled? do
        !can
      end

      req
    end

    # What happens when a connection is closed for any reason.
    def unbind
      raise "No more doozers!"
    end

  end

end
