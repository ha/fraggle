require 'fraggle/msg.pb'

module Fraggle
  class Request

    def initialize(attrs={})
      super(attrs)
      @cb = Hash.new(lambda {})
    end

    def valid(&blk)
      @cb[:valid] = blk
    end

    def done(&blk)
      @cb[:done] = blk
    end

    def error(&blk)
      @cb[:error] = blk
    end

    def emit(name, *args)
      @cb[name].call(*args)
    end

  end
end
