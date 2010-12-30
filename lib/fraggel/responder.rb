module Fraggel

  class Responder

    def initialize(&blk)
      @receiver = blk
    end

    def receive_event(name, value)
      receive_event! name, value do |x|
        @receiver.call(x)
      end
    end

    def receive_event!(name, value, &blk)
      @rcs ||= lambda {|x|
        blk.call(x)
        @rcs = nil
      }

      case name
      when :array
        @rcs = array!(value, [], &@rcs)
      else
        @rcs.call(value)
      end
    end

    def array!(c, a, &blk)
      lambda {|x|
        a << x
        if c == a.length
          blk.call(a)
          @rcs = blk
        else
          array!(c, a, &blk)
        end
      }
    end

  end

end
