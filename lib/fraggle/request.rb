require 'fraggle/msg.pb'

module Fraggle
  class Request
    DEFAULT_PROC = Proc.new {}

    attr_reader   :cb

    def valid(&blk)
      @blk = blk
    end

    def call(e)
      return if ! @blk
      @blk.call(e)
    end
  end
end
