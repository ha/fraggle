require 'fraggle/response'

module Fraggle

  module Protocol

    attr_reader :last_received

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
      p res
    end

    def send_request(req)
      data = req.encode
      head = [data.length].pack("N")

      send_data("#{head}#{data}")
    end

    def send_data(data)
      super(data)
    end

  end

end
