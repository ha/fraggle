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
      
      @nested_array = false
    end
    
    def buf
      @buf
    end

    def next(bytes)
      @buf << bytes
      case @cs
      when :line
        while line = @buf.slice!(/.+\r\n/)
          (line ||= "").chomp!
          
          puts "next, line: #{line.inspect}, buf: #{buf.inspect}"
          
          case line[0]
          when ?*
            old_count = @count
            @count = Integer(line[1..-1])
            
            if @nested_array
              nested_buf = "*#{@count}\r\n#{@buf}"
              
              nested_scanner = Scanner.new
              nested_result = nested_scanner.next(nested_buf)
              puts "result: #{nested_result.inspect}"
              puts "remaining bytes: #{nested_scanner.buf.inspect}"
              
              @parts << nested_result
              
              @buf = nested_scanner.buf
              @cs = :line
              
              @count = old_count
              
              return self.next('')
              
              puts "recursion?: #{nested_buf.inspect}, result: #{Scanner.new.next(nested_buf).inspect}"
            else
              @nested_array = true
            end
            
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
          
          puts "parts size: #{@parts.size}, count: #{@count}"
          if @parts.size == @count
            
            # may need to reset this explicitly
            #@buf   = ''
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
