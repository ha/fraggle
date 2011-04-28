require 'fraggle/msg.pb'

module Fraggle
  class Request
    DEFAULT_PROC = Proc.new {}

    def valid(&blk)
      @blk = blk
    end

    def call(e)
      return if ! @blk
      @blk.call(e)
    end
  end
end
