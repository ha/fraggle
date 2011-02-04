require 'fraggle/response'

module Fraggle

  module Protocol

    def receive_data(data)
      (@buf ||= "") << data

      p [:buf, @buf]

      while @buf.length > 0
        if @len && @buf.length >= @len
          bytes = @buf.slice!(0, @len)
          res = Response.decode(bytes)
          receive_response(res)
          @len = nil
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
