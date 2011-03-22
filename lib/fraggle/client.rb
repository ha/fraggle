require 'fraggle/errors'
require 'fraggle/logger'
require 'fraggle/meta'
require 'fraggle/protocol'
require 'fraggle/request'
require 'fraggle/response'
require 'set'
require 'uri'

module Fraggle

  module Client
    include Protocol
    include Logger

    class Error < StandardError ; end


    MinTag = 0
    MaxTag = (1<<32)

    Nibbles = "0123456789abcdef"

    def initialize(addr, addrs=[], opts={})
      @cbx   = {}

      @addr  = addr
      @addrs = {}

      addrs.each_with_index do |addr, i|
        @addrs[i] = addr
      end

      # Logging
      @level   = opts[:level] || ERROR
      @writer  = $stderr
    end

    def receive_response(res)
      debug "received response: #{res.inspect}"

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

    def rev
      req = Request.new
      req.verb = Request::Verb::REV

      resend(req)
    end

    def checkin(path, rev)
      req = Request.new
      req.verb = Request::Verb::CHECKIN
      req.path = path
      req.rev  = casify(rev)

      resend(req)
    end

    def session(prefix=nil, &blk)
      name    = "#{prefix}#{genkey}"
      estab   = false

      f = Proc.new do |e|
        # If this is the first response from the server, it's go-time.
        if ! estab
          blk.call(name)
        end

        # We've successfully established a session.  Say so.
        estab = true

        # Get back to the server ASAP
        checkin(name, e.rev).valid(&f)
      end

      checkin(name, 0).valid(&f)
    end

    def get(rev, path)
      req = Request.new
      req.rev  = rev
      req.verb = Request::Verb::GET
      req.path = path

      resend(req)
    end

    def stat(rev, path)
      req = Request.new
      req.rev  = rev
      req.verb = Request::Verb::STAT
      req.path = path

      resend(req)
    end

    def getdir(rev, path, offset, limit)
      req = Request.new
      req.rev    = rev
      req.verb   = Request::Verb::GETDIR
      req.offset = offset if offset != 0
      req.limit  = limit  if limit  != 0
      req.path   = path

      resend(req)
    end

    def set(path, value, rev)
      req = Request.new
      req.verb  = Request::Verb::SET
      req.path  = path
      req.value = value
      req.rev   = casify(rev)

      send(req)
    end

    def del(path, rev)
      req = Request.new
      req.verb  = Request::Verb::DEL
      req.path  = path
      req.rev   = casify(rev)

      send(req)
    end

    def walk(rev, glob, offset=nil, limit=nil)
      req = Request.new
      req.verb   = Request::Verb::WALK
      req.rev    = rev
      req.path   = glob
      req.offset = offset
      req.limit  = limit

      cancelable(resend(req))
    end

    def watch(rev, glob)
      req = Request.new
      req.rev  = rev
      req.verb = Request::Verb::WATCH
      req.path = glob

      cancelable(resend(req))
    end

    def monitor(rev, glob)
      req = Request.new
      req.rev  = rev
      req.path = glob

      wt = nil
      wk = nil

      req.metadef :cancel do
        wt.cancel if wt
        wk.cancel if wk
      end

      wk = walk(rev, glob).valid do |e|
        req.emit(:valid, e)
      end.error do |e|
        req.emit(:error, e)
      end.done do
        req.emit(:done)

        wt = watch(rev+1, glob).valid do |e|
          req.emit(:valid, e)
        end.error do |e|
          req.emit(:error, e)
        end
      end

      req
    end

    def noop(&blk)
      req = Request.new
      req.verb = Request::Verb::NOOP

      send(req)
    end

    # Be careful with this.  It is recommended you use #cancel on the Request
    # returned to ensure you don't run into a race-condition where you cancel an
    # operation you may have thought was something else.
    def __cancel__(what)
      req = Request.new
      req.verb = Request::Verb::CANCEL
      req.id = what.tag

      # Hold on to the tag as unavaiable for reuse until the cancel succeeds.
      @cbx[what.tag] = nil

      send(req).valid do |res|
        # Do not send any more responses from the server to this request.
        @cbx.delete(what.tag)
        what.emit(:valid, res)
      end
    end

    def next_tag
      tag = MinTag

      while @cbx.has_key?(tag)
        tag += 1
        if tag > MaxTag
          tag = MinTag
        end
      end

      tag
    end

    def send(req)
      req.tag ||= next_tag

      @cbx[req.tag] = req

      debug "sending request:   #{req.inspect}"
      send_request(req)

      req
    end

    def resend(req)
      req.tag ||= next_tag

      wrap = Request.new(req.to_hash)

      req.valid do |e|
        if req.offset
          req.offset += 1
        end

        if req.limit
          req.limit -= 1
        end

        if (req.rev || 0) < (e.rev || 0)
          req.rev = e.rev
        end

        wrap.emit(:valid, e)
      end

      req.error do |err|
        if err.disconnected?
          send(req)
        else
          wrap.emit(:error, err)
        end
      end

      req.done do
        wrap.emit(:done)
      end

      send(req)

      wrap
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

    def post_init
      info "successfully connected to #{@addr}"

      res = Response.new(:err_code => Errno::ECONNREFUSED::Errno)
      @cbx.values.compact.each do |req|
        debug "sending disconnected error to #{req.inspect}"
        req.emit(:error, res)
      end

      if ! @tracking
        trackaddrs
        @tracking = true
      end
    end

    # Track addresses of doozers in a cluster.  This will retry
    # in the event of a new connection.
    def trackaddrs
      rev.valid do |v|
        monitor(v.rev, "/doozer/slot/*").valid do |e|
          if e.value == ""
            @addrs.delete(e.path)
          else
            get(e.rev, "/doozer/info/#{e.value}/addr").valid do |g|
              next if g.value == @addr
              @addrs[e.path] = g.value
            end
          end
        end.error do |err|
          error "address tracking: #{err.inspect} for #{req.inspect}"
        end
      end
    end

    # What happens when a connection is closed for any reason.
    def unbind
      info "disconnected from #{@addr}"

      _, @addr = @addrs.shift
      if ! @addr
        raise "No more addrs"
      end

      host, port = @addr.split(":")

      info "attempting connection to #{@addr}"

      reconnect(host, port.to_i)

      post_init
    end

    def casify(cas)
      case cas
      when :missing then Response::Missing
      when :clobber then Response::Clobber
      else cas
      end
    end

    def genkey
      (0...16).map { Nibbles[rand(Nibbles.length)].chr }.join
    end

  end

end
