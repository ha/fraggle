require 'fraggle/msg.pb'

module Fraggle
  class Request

    DEFAULT_PROC = Proc.new {}

    attr_accessor :cn
    attr_reader   :cb

    def initialize(attrs={})
      super(attrs)
      @cb = Hash.new
    end

    def valid(&blk)
      @cb[:valid] = blk
      self
    end

    def emit(name, *args)
      (@cb[name] || DEFAULT_PROC).call(*args)
    end

  end
end
