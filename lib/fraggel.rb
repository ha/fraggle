require 'eventmachine'

class Fraggel

  Closed = 1
  Last   = 2

  def self.connect(host, port)
    EM.connect(host, port, Connection)
  end


  class Parser
    def initialize(&blk)
      @buf = ''
      @reader = nil
      @stream_error = false
      main(&blk)
    end

    def main(&blk)
      parse do |x, err|
        blk.call(x, err)
        main(&blk)
      end
    end

    def receive_data(data)
      raise if @stream_error
      @buf << data
      check
    end

    def fr_read(n, &blk)
      @reader = {:block => blk, :num => n}
      check
    end

    def fr_readline(&blk)
      @reader = {:block => blk, :line => true}
      check
    end

    def check
      r = @reader
      return if r.nil?

      if r[:num] && @buf.length >= r[:num]
        @reader = nil
        r[:block].call(@buf.slice!(0, r[:num]))
        return
      end

      if r[:line] && s = @buf.slice!(/.+\r\n/)
        @reader = nil
        r[:block].call(s)
      end
    end

    def read_array_items(arrayLength, &blk)
      f = lambda { |items, err|
        parse do |item, err|
          if items.length < (arrayLength - 1)
            f.call(items << item, err)
          else
            blk.call(items << item, err)
          end
        end
      }
      f.call([], nil)
    end

    def parse(&blk)
      fr_read(1) do |c|
        if c == ':'
          fr_readline do |line|
            blk.call(line.to_i, nil)
          end
        elsif c == '$'
          fr_readline do |dataLength|
            fr_read(dataLength.to_i + 2) do |data|
              if data[dataLength.to_i, 2] != "\r\n"
                raise StandardError, 'stream error'
              else
                blk.call(data[0, dataLength.to_i], nil)
              end
            end
          end
        elsif c == '*'
          fr_readline do |arrayLength|
            read_array_items(arrayLength.to_i, &blk)
          end
        elsif c == '+'
          fr_readline do |line|
            blk.call(line, nil)
          end
        elsif c == '-'
          fr_readline do |line|
            blk.call(nil, line)
          end
        else
          raise StandardError, 'stream error'
        end
      end
    end
  end

  class Connection < EM::Connection
    def post_init
      @opid = 0
      @cbs  = Hash.new { Proc.new {} }
      @parser = Parser.new do |value, err|
        receive_value(value, err)
      end
    end

    def receive_data(data)
      @parser.receive_data(data)
    end

    def receive_value(response, err)
      opid, flags, data = response
      p [:response, opid, flags, data, err]
      if flags&Closed == 0
        @cbs[opid].call(data, err)
      end
      if flags&(Last|Closed) != 0
        @cbs.delete(opid)
      end
    end

    def call(verb, args, &blk)
      @opid += 1
      @cbs[@opid] = blk
      send_data(encode([verb, @opid, args]))
      @opid
    end

    def encode(arg)
      case arg
      when Array
        "*%d\r\n%s" % [
          arg.length,
          arg.map {|x| encode(x) }
        ]
      when Integer
        ":#{arg}\r\n"
      else
        str = arg.to_str
        "$%d\r\n%s\r\n" % [str.length, str]
      end
    end

  end

end
