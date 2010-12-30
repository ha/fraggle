module Fraggel

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
