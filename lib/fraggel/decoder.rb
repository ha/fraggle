module Fraggel

  module Decoder

    class Poisioned < StandardError ; end

    def receive_data(data)
      @buf ||= ""
      @buf << data

      if ! @dcs
        read_type
      else
        @dcs.call
      end
    end

    def dcs(&blk)
      @dcs = blk
      @dcs.call
    end

    def read_type
      dcs do
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
      dcs do
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
      dcs do
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
        dcs do
          if @buf.length >= count
            string = @buf.slice!(0, count)
            dcs do
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
      dcs do
        if line = @buf.slice!(/.*\r/)
          finish do
            blk.call(line.chomp)
          end
        end
      end
    end

  end

end
