require 'fraggle/msg.pb'

module Fraggle
  class Response

    VALID = 1
    DONE  = 2
    SET   = 4
    DEL   = 8

    attr_accessor :disconnected

    def valid?
      return false if !flags
      (flags & VALID) > 0
    end

    def done?
      return false if !flags
      (flags & DONE) > 0
    end

    def set?
      return false if !flags
      (flags & SET) > 0
    end

    def del?
      return false if !flags
      (flags & DEL) > 0
    end

    def missing?
      rev == 0
    end

    def ok?
      err_code.nil?
    end

    def readonly?
      err_code == Err::READONLY
    end

    def disconnected?
      !!@disconnected
    end

  end
end
