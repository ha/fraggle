require 'eventmachine'

class Fraggel < EM::Connection


  class Parser
    def initialize
      @buf = ''
      @pending_read = nil
      @pending_readline = nil
      @stream_error = false
    end

    def receive_data(data)
      raise Exception.new('stream error') if @stream_error

      @buf << data

      if not @pending_read.nil? and @buf.length >= @pending_read[:num]
        pr = @pending_read
        @pending_read = nil
        fr_read(pr[:num], &pr[:block])
      elsif not @pending_readline.nil?
        prl = @pending_readline[:block]
        @pending_readline = nil
        fr_readline(&prl)
      end
    end

    def fr_read(n, &blk)
      if @buf.length < n
        @pending_read = {:num => n, :block => blk}
      else
        blk.call(@buf.slice!(0, n))
      end
    end

    def fr_readline(&blk)
      line = @buf.slice!(/.+\r\n/)
      if line.nil?
        @pending_readline = {:block => blk}
      else
        blk.call(line)
      end
    end

    def read_array_items(arrayLength, &blk)
      f = lambda { |items|
        parse do |item|
          if items.length < (arrayLength - 1)
            f.call(items << item)
          else
            blk.call(items << item)
          end
        end
      }
      f.call([])
    end

    def parse(&blk)
      fr_read(1) do |c|
        if c == ':'
          fr_readline do |line|
            blk.call(line.to_i)
          end
        elsif c == '$'
          fr_readline do |dataLength|
            fr_read(dataLength.to_i + 2) do |data|
              if data[dataLength.to_i, 2] != "\r\n"
                @stream_error = true
                blk.call(:invalid_format)
              else
                blk.call(data[0, dataLength.to_i])
              end
            end
          end
        elsif c == '*'
          fr_readline do |arrayLength|
            read_array_items(arrayLength.to_i) do |items|
              blk.call(items)
            end
          end
        else
          @stream_error = true
          blk.call(:fatal_error)
        end
      end
    end
  end

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

          case line[0]
          when ?*
            old_count = @count
            @count = Integer(line[1..-1])

            if @nested_array
              nested_buf = "*#{@count}\r\n#{@buf}"

              nested_scanner = Scanner.new
              nested_result = nested_scanner.next(nested_buf)

              @parts << nested_result

              @buf = nested_scanner.buf
              @cs = :line

              @count = old_count

              return self.next('')
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
