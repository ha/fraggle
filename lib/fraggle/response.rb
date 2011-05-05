require 'fraggle/msg.pb'

module Fraggle
  class Response

    SET   = 4
    DEL   = 8

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

  end
end
