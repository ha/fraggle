module Fraggel

  module Decoder

    class Poisioned < StandardError ; end

    def receive_data(data)
      @buf ||= ""
      @buf << data

      if ! @cs
        read_type
      else
        @cs.call
      end
    end

    def cs(&blk)
      @cs = blk
      @cs.call
    end

    def read_type
      cs do
        case @buf.slice!(0)
        when nil
          # Wait for next byte
        when ?\r
          finish do
            read_type
          end
        when ?:
          read_integer do |i|
            receive_event(:value, i)
            read_type
          end
        when ?$
          read_string do |s|
            receive_event(:value, s)
            read_type
          end
        when ?+
          read_line do |msg|
            receive_event(:status, msg)
            read_type
          end
        when ?-
          read_line do |msg|
            receive_event(:error, msg)
            read_type
          end
        when ?*
          read_integer do |count|
            receive_event(:array, count)
            read_type
          end
        else
          raise Poisioned
        end
      end
    end

    def finish(&blk)
      cs do
        c = @buf.slice!(0)
        case c
        when nil
          # Wait for next byte
        when ?\n
          blk.call
        else
          raise Poisioned
        end
      end
    end

    def read_integer(&blk)
      @int = ""
      cs do
        while c = @buf.slice!(0)
          case c
          when ?0..?9
            @int << c.chr
          when ?\r
            finish do
              blk.call(Integer(@int))
            end
          else
            raise Poisioned
          end
        end
      end
    end

    def read_string(&blk)
      read_integer do |count|
        cs do
          if @buf.length >= count
            string = @buf.slice!(0, count)
            cs do
              case @buf.slice!(0)
              when nil
                # Wait for next byte
              when ?\r
                finish do
                  blk.call(string)
                end
              else
                raise Poisioned
              end
            end
          end
        end
      end
    end

    def read_line(&blk)
      cs do
        if line = @buf.slice!(/.*\r/)
          finish do
            blk.call(line.chomp)
          end
        end
      end
    end

  end


  module Encoder

    def encode(value)
      case value
      when nil
        "$-1\r\n"
      when true
        encode(1)
      when false
        encode(0)
      when Integer
        ":%d\r\n" % [value]
      when String
        "$%d\r\n%s\r\n" % [value.length, value]
      when Array
        mapped = value.map {|x| encode(x) }
        "*%d\r\n%s" % [mapped.length, mapped]
      when StandardError, Exception
        "-ERR: %s\r\n" % [value.message]
      end
    end

  end


  module Responder

    def receive_event(name, value)
      receive_event! name, value do |x|
        receive_response(x)
      end
    end

    def receive_event!(name, value, &blk)
      @cs ||= lambda {|x|
        blk.call(x)
        @cs = nil
      }

      case name
      when :array
        @cs = array!(value, [], &@cs)
      else
        @cs.call(value)
      end
    end

    def array!(c, a, &blk)
      lambda {|x|
        a << x
        if c == a.length
          blk.call(a)
          @cs = blk
        else
          array!(c, a, &blk)
        end
      }
    end

  end

end
