## Generated from msg.proto for proto
module Fraggle

class Request
  include Beefcake::Message

  module Verb
    CHECKIN = 0
    GET = 1
    SET = 2
    DEL = 3
    ESET = 4
    REV = 5
    NOOP = 7
    WATCH = 8
    WALK = 9
    CANCEL = 10
    GETDIR = 14
    STAT = 16
    MONITOR = 11
    SYNCPATH = 12
  end

  required :tag, :int32, 1
  required :verb, Request::Verb, 2
  optional :path, :string, 4
  optional :value, :bytes, 5
  optional :id, :int32, 6
  optional :offset, :int32, 7
  optional :limit, :int32, 8
  optional :rev, :int64, 9

end

class Response
  include Beefcake::Message

  module Err
    OTHER = 127
    TAG_IN_USE = 1
    UNKNOWN_VERB = 2
    REDIRECT = 3
    TOO_LATE = 4
    CAS_MISMATCH = 5
    BAD_PATH = 6
    MISSING_ARG = 7
    NOTDIR = 20
    ISDIR = 21
    NOENT = 22
  end

  required :tag, :int32, 1
  required :flags, :int32, 2
  optional :rev, :int64, 3
  optional :cas, :int64, 4
  optional :path, :string, 5
  optional :value, :bytes, 6
  optional :id, :int32, 7
  optional :len, :int32, 8
  optional :err_code, Response::Err, 100
  optional :err_detail, :string, 101

end
end
