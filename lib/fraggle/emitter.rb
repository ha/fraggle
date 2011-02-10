module Fraggle

  module Emitter

    def callbacks
      @callbacks ||= Hash.new(lambda {})
    end

    def emit(name, *args)
      callbacks[name].call(*args)
    end

    def valid(&blk) ; must_callback!(:valid, blk) ; end
    def done(&blk)  ; must_callback!(:done,  blk) ; end
    def error(&blk) ; must_callback!(:error, blk) ; end

    def must_callback!(name, blk)
      if ! blk
        raise ArgumentError, "no block given to `#{name}`"
      end
      callbacks[name] = blk
    end

    def aggr(coll=[], &blk)
      valid do |item|
        coll << item
      end

      done do
        blk.call(coll)
      end
    end

  end

end
