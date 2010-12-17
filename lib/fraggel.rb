module Fraggel

  module Parser

    class Poisioned < StandardError ; end

    def emit(msg, v) ; end

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
            emit(:part, i)
            read_type
          end
        when ?$
          read_string do |s|
            emit(:part, s)
            read_type
          end
        when ?+
          read_line do |msg|
            emit(:true, msg)
            read_type
          end
        when ?-
          read_line do |msg|
            emit(:false, msg)
            read_type
          end
        when ?*
          read_integer do |count|
            emit(:array, count)
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

end
