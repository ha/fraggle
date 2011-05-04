## Generated from msg.proto for server
require "beefcake"

module Fraggle

  class Request
    include Beefcake::Message

    module Verb
      GET = 1
      SET = 2
      DEL = 3
      REV = 5
      WAIT = 6
      NOP = 7
      WALK = 9
      GETDIR = 14
      STAT = 16
      ACCESS = 99
    end

    optional :tag, :int32, 1
    optional :verb, Request::Verb, 2
    optional :path, :string, 4
    optional :value, :bytes, 5
    optional :other_tag, :int32, 6
    optional :offset, :int32, 7
    optional :rev, :int64, 9

  end

  class Response
    include Beefcake::Message

    module Err
      OTHER = 127
      TAG_IN_USE = 1
      UNKNOWN_VERB = 2
      READONLY = 3
      TOO_LATE = 4
      REV_MISMATCH = 5
      BAD_PATH = 6
      MISSING_ARG = 7
      RANGE = 8
      NOTDIR = 20
      ISDIR = 21
      NOENT = 22
    end

    optional :tag, :int32, 1
    optional :flags, :int32, 2
    optional :rev, :int64, 3
    optional :path, :string, 5
    optional :value, :bytes, 6
    optional :len, :int32, 8
    optional :err_code, Response::Err, 100
    optional :err_detail, :string, 101

  end
end
