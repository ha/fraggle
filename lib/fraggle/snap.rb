require 'fraggle/client'

module Fraggle

  class Snap

    attr_reader :id, :rev, :c

    def initialize(id, c, rev=nil)
      @id  = id
      @c   = c
      @rev = rev
    end

    def get(path, &blk)
      @c.get(@id, path, &blk)
    end

    def walk(glob, &blk)
      @c.walk(@id, glob, &blk)
    end

    def stat(path, &blk)
      @c.stat(@id, path, &blk)
    end

    def getdir(path, offset=0, limit=0, &blk)
      @c.getdir(@id, path, offset, limit, &blk)
    end

    def snap(&blk)
      @c.snap do |res|
        sn = Snap.new(res.id, @c, res.rev)
        blk.call(sn)
      end
    end

    def delete(&blk)
      @c.delsnap(@id, &blk)
    end

    def send(req, &blk)
      @c.send(req, &blk)
    end

    def method_missing(*args, &blk)
      @c.__send__(*args, &blk)
    end

  end

end
