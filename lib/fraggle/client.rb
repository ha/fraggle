require 'fraggle/meta'
require 'fraggle/protocol'
require 'fraggle/request'
require 'fraggle/response'
require 'logger'
require 'uri'

module Fraggle

  module Client
    include Protocol

    class Error < StandardError ; end


    MinTag = 0
    MaxTag = (1<<32)


    def initialize(uri, log=Logger.new("/dev/null"))
      # Simplied for now.  Later we'll take a real uri
      # and disect it to init the addrs list
      uri = URI(uri.to_s)

      @addr  = [uri.host, uri.port] * ":"
      @addrs = {}
      @shun  = {}
      @cbx   = {}
      @log   = log
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
      req.cas   = casify(cas)

      send(req, &blk)
    end

    def get(sid, path, &blk)
      req = Request.new
      req.verb = Request::Verb::GET
      req.id   = sid if sid != 0 # wire optimization
      req.path = path

      send(req, &blk)
    end

    def stat(sid, path, &blk)
      req = Request.new
      req.verb = Request::Verb::STAT
      req.id   = sid if sid != 0 # wire optimization
      req.path = path

      send(req, &blk)
    end

    def getdir(sid, path, offset, limit, &blk)
      req = Request.new
      req.verb   = Request::Verb::GETDIR
      req.id     = sid    if sid != 0
      req.offset = offset if offset != 0
      req.limit  = limit  if limit  != 0
      req.path   = path

      send(req, &blk)
    end

    def set(path, value, cas, &blk)
      req = Request.new
      req.verb  = Request::Verb::SET
      req.path  = path
      req.value = value
      req.cas   = casify(cas)

      send(req, &blk)
    end

    def del(path, cas, &blk)
      req = Request.new
      req.verb  = Request::Verb::DEL
      req.path  = path
      req.cas   = casify(cas)

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
        raise Error.new("'error (%d) (%s)' for: %s" % [
          e.err_code,
          e.err_detail.inspect,
          req.inspect
        ])
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

    def post_init
      @log.info "successfully connected to #{@addr}"

      @last_received = Time.now

      EM.add_periodic_timer(2) do
        if (n = Time.now - last_received) >= 3
          @log.error("timedout talking to #{@addr}")
          close_connection
        else
          @log.debug("ping")
          get(0, "/ping") { @log.debug("pong") }
        end
      end

      waw = Proc.new do |e|
        if e.value == ""
          addr = @addrs.delete(e.path)
          if addr
            @log.error "noticed #{addr} is gone; removing"
          end
        else
          get 0, "/doozer/info/#{e.value}/public-addr" do |a|
            if @shun.has_key?(a.value)
              if (n = Time.now - @shun[a.value]) > 3
                @log.info "pardoning #{a.value} after #{n} secs"
                @shun.delete(a.value)
              else
                @log.info "ignoring shunned addr #{a.value}"
                next
              end
            end
            # TODO: Be defensive and check the addr value is valid
            @addrs[e.path] = a.value
            @log.info("added #{e.path} addr #{a.value}")
          end
        end
      end

      watch    "/doozer/slot/*", &waw
      walk  0, "/doozer/slot/*", &waw
    end

    # What happens when a connection is closed for any reason.
    def unbind
      @log.error "disconnected from #{@addr}"

      # Shun the address we were currently attempting/connected to.
      @shun[@addr] = Time.now
      @addrs.delete_if {|_, v| v == @addr }

      # We don't want the timer to race us while
      # we're trying to reconnect.  Once the reconnect
      # has been complete, we'll start the timer again.
      EM.cancel_timer(@timer)

      _, @addr = @addrs.shift rescue nil

      if ! @addr
        # We are all out of addresses to try
        raise "No more doozers!"
      end

      host, port = @addr.split(":")
      @log.info "attempting reconnect to #{host}:#{port}"
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

  end

end
