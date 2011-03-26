require 'fraggle/request'
require 'fraggle/response'

module Fraggle

  module Connection

    # Base class for all Connection errors
    class Error < StandardError
      attr_accessor :req

      def initialize(req, msg=nil)
        @req = req
        super(msg)
      end
    end

    # Raised when a request is invalid
    class SendError < Error
    end


    attr_reader :last_received, :addr

    def initialize(addr)
      @addr = addr
      @cb   = {}
    end

    def receive_data(data)
      @last_received = Time.now

      (@buf ||= "") << data

      while @buf.length > 0
        if @len && @buf.length >= @len
            bytes = @buf.slice!(0, @len)
            @len = nil
            res = Response.decode(bytes)
            receive_response(res)
        elsif @buf.length >= 4
          bytes = @buf.slice!(0, 4)
          @len = bytes.unpack("N")[0]
        else
          break
        end
      end
    end

    # The default receive_response
    def receive_response(res)
      req = @cb[res.tag]

      if ! req
        return
      end

      if ! res.ok?
        @cb.delete(req.tag)
        req.emit(:error, res)
        return
      end

      if res.done?
        @cb.delete(req.tag)
        req.emit(:done)
      end

      if res.valid?
        req.emit(:valid, res)
      end
    end

    def send_request(req)
      if req.tag
        raise SendError, "Already sent #{req.inspect}"
      end

      if error?
        req.emit(:error, nil)
        return req
      end

      req.tag = 0
      while @cb.has_key?(req.tag)
        req.tag += 1

        req.tag %= 2**31
      end

      req.cn = self

      @cb[req.tag] = req

      data = req.encode
      head = [data.length].pack("N")

      send_data("#{head}#{data}")

      req
    end

    def post_init
      last = 0
      rev  = Request.new :verb => Request::Verb::REV

      rev.valid do |e|
        if e.rev <= last
          close_connection
        else
          timer(5) { send_request(rev.dup) }
          last = e.rev
        end
      end

      send_request(rev.dup)
    end

    def unbind
      @cb.values.each do |req|
        req.emit(:error, nil)
      end
    end

    def timer(n, &blk)
      EM.add_timer(n, &blk)
    end

  end

end
