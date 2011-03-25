require 'fraggle/request'
require 'fraggle/response'

module Fraggle

  module Connection

    class Error < StandardError
      attr_accessor :req, :res

      def initialize(req, res)
        @req, @res = req, res
      end
    end

    class Disconnected < Error         ; end
    class SendError < StandardError ; end

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
