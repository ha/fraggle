require 'fraggle/request'
require 'fraggle/response'

module Fraggle

  ##
  # I want this to be a great starting point for testing fraggle applications.
  # It's currently a work in progress.  Think Rack::Test for fraggle.
  #
  module Test

    V = Fraggle::Request::Verb
    F = Fraggle::Response::Flag
    E = Fraggle::Response::Err


    class TestClient < Array
      include Fraggle::Client
      alias :send_request :<<
    end


    # This is handy for testing callbacks
    class Blk < Array
      def to_proc
        Proc.new {|res| self << res }
      end
    end


    def assert_sent(tag, attrs={})
      req = Fraggle::Request.new(attrs)
      req.tag = tag

      msg =  "This was not sent:\n"
      msg << "  #{req.inspect}\n"
      msg << "Sent:\n  "
      msg << c.map {|r| r.inspect }.join("\n  ")
      msg << "\n"

      assert_block(msg) { c.include?(req) }
    end

    def assert_recv(attrs)
      req = Fraggle::Response.new(attrs)
      msg =  "This was not recieved:\n"
      msg << "  #{req.inspect}\n"
      msg << "Received:\n  "
      msg << blk.map {|r| r.inspect }.join("\n  ")
      msg << "\n"

      assert_block(msg) { blk.include?(attrs) }
    end

    # Replies with a valid response
    def reply(tag, attrs={})
      res = Fraggle::Response.new(attrs)
      res.tag   = tag
      res.flags ||= 0
      res.flags |= Fraggle::Response::Flag::VALID
      c.receive_response(res)
      res
    end

    # Replies with a valid + done response
    def reply!(tag, attrs={})
      reply(tag, attrs.merge(:flags => Fraggle::Response::Flag::DONE))
    end

  end

end
