require 'eventmachine'

class Fraggel < EM::Connection

  class Scanner
    unless defined?(Empty)
      Delim = "\r\n"
      Empty = ""
    end

    def initialize
      @cs    = :line
      @count = 1
      @size  = nil  # TODO: find a better default
      @buf   = ''
      @parts = []
    end

    def next(bytes)
      @buf << bytes
      case @cs
      when :line
        while line = @buf.slice!(/.+\r\n/)
          (line ||= "").chomp!
          case line[0]
          when ?*
            @count = Integer(line[1..-1])
          when ?$
            @size = Integer(line[1..-1])
            @cs = :raw
            return self.next('')
          end
        end
      when :raw
        if @buf.size >= @size
          @parts << @buf.slice!(0, @size)
          @buf.slice!(0,2) # remove the tailing \r\n
          @cs = :line
          if @parts.size == @count
            @buf   = ''
            result, @parts = @parts, []
            return result
          else
            return self.next('')
          end
        end
      end
    end
  end
end
