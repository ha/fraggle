require 'fraggle/response'

module Fraggle

  module Connection

    # Raised when a request is invalid
    class SendError < StandardError
      def initialize(req, msg=nil)
        @req = req
        super(msg)
      end
    end

    class DisconnectedError < StandardError
      def ==(o)
        return false if ! o.kind_of?(self.class)
        message == o.message
      end
    end

    class ResponseError < StandardError
      attr_reader :code

      alias :detail :message

      def initialize(res)
        @code = res.err_code
        super("#{res.name_for(Response::Err, code)}: #{res.err_detail}")
      end

      def ==(o)
        return false if ! o.kind_of?(self.class)
        code == o.code && message == o.message
      end
    end


    attr_reader :addr

    def initialize(addr)
      @addr, @cb = addr, {}
    end

    def receive_data(data)
      (@buf ||= "") << data

      while @buf.length > 0
        if not @len
          # Get content length of response from first 4 bytes
          if @buf.length < 4
            # We do not have enough bytes for length yet.
            break
          end
          # Decode content length from first 4 bytes.
          bytes = @buf.slice!(0, 4)
          @len = bytes.unpack("N")[0]
        elsif @buf.length >= @len
          # We have enough bytes to decode response.
          bytes = @buf.slice!(0, @len)
          @len = nil
          res = Response.decode(bytes)
          # Return response.
          receive_response(res)
        else
          # Not enough bytes for our response yet.
          # Wait for next call to receive_data.
          break
        end
      end
    end

    # The default receive_response
    def receive_response(res)
      return if err?
      req, blk = @cb.delete(res.tag)
      return if ! blk
      if res.err_code
        blk.call(nil, ResponseError.new(res))
      else
        blk.call(res, nil)
      end
    end

    def send_request(req, blk)
      if req.tag
        raise SendError, "Already sent #{req.inspect}"
      end

      if err?
        next_tick { blk.call(nil, DisconnectedError.new(self.addr)) }
        return req
      end

      req.tag = 0
      while @cb.has_key?(req.tag)
        req.tag += 1

        req.tag %= 2**31
      end

      # TODO: remove this!
      @cb[req.tag] = [req, blk]

      data = req.encode
      head = [data.length].pack("N")

      send_data("#{head}#{data}")

      req
    end

    def unbind
      @err = true
      @cb.values.each do |_, blk|
        blk.call(nil, DisconnectedError.new(self.addr))
      end
    end

    def err?
      !!@err
    end

    def timer(n, &blk)
      EM.add_timer(n, &blk)
    end

    def next_tick(&blk)
      EM.next_tick(&blk)
    end

  end

end
