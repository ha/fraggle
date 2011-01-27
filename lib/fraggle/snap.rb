require 'fraggle/client'

module Fraggle

  class Snap

    attr_reader :id

    def initialize(id, c)
      @id = id
      @c  = c
    end

    def get(path, &blk)
      @c.get(@id, path, &blk)
    end

    def walk(glob, &blk)
      @c.walk(@id, glob, &blk)
    end

    def snap(&blk)
      @c.snap do |res|
        sn = Snap.new(res.id, @c)
        blk.call(sn)
      end
    end

    def method_missing(*args, &blk)
      @c.__send__(*args, &blk)
    end

  end

end
