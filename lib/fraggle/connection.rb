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

    # Emitted to requests when a connection is disconnected
    class Disconnected < Error
      def initialize(req, addr)
        super(req, "disconnected from #{addr}")
      end
    end

    # Raised when a request is invalid
    class SendError < Error
    end


    attr_reader :last_received

    def initialize
      @cb = {}
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

  end

end
