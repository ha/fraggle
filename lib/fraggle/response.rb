require 'fraggle/msg.pb'

module Fraggle
  class Response

    VALID = 1
    DONE  = 2

    def valid?
      return false if !flags
      (flags & VALID) > 0
    end

    def done?
      return false if !flags
      (flags & DONE) > 0
    end

    def ok?
      err_code.nil?
    end

  end
end
