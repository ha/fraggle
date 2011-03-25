require 'fraggle/msg.pb'

module Fraggle
  class Request

    attr_accessor :cn

    def initialize(attrs={})
      super(attrs)
      @cb = Hash.new(lambda {})
    end

    def valid(&blk)
      @cb[:valid] = blk
      self
    end

    def done(&blk)
      @cb[:done] = blk
      self
    end

    def error(&blk)
      @cb[:error] = blk
      self
    end

    def emit(name, *args)
      @cb[name].call(*args)
    end

    def cancel
      @can ||= Request.new(:verb => Verb::CANCEL, :other_tag => self.tag)
      cn.send_request(@can)
    end

  end
end
