require 'beefcake'

module Fraggle

  class Request
    include Beefcake::Message

    required :tag, :int32, 1

    module Verb
      CHECKIN  = 0;  # rev, id          => rev
      GET      = 1;  # path, id         => rev, value
      SET      = 2;  # rev, path, value => rev
      DEL      = 3;  # rev, path        => {}
      ESET     = 4;  # rev, path        => {}
      REV      = 5;  # {}               => seqn, id
      NOOP     = 7;  # {}               => {}
      WATCH    = 8;  # path             => {rev, path, value}+
      CANCEL   = 10; # id               => {}
      STAT     = 16; # path, id         => rev, len

      # future
      GETDIR   = 14; # path             => {rev, value}+
      MONITOR  = 11; # path             => {rev, path, value}+
      SYNCPATH = 12; # path             => rev, value
      WALK     = 9;  # path, id         => {rev, path, value}+

      # deprecated
      JOIN     = 13;
    end

    required :verb, Verb, 2

    optional :path,  :string, 4
    optional :value, :bytes,  5
    optional :id,    :int32,  6

    optional :offset, :int32, 7
    optional :limit,  :int32, 8

    optional :rev,    :int64, 9
  end


  class Response
    include Beefcake::Message

    required :tag,   :uint32, 1
    required :flags, :int32, 2

    optional :rev,   :int64,  3
    optional :cas,   :int64,  4
    optional :path,  :string, 5
    optional :value, :bytes,  6
    optional :id,    :int32,  7
    optional :len,   :int32,  8

    module Flag
      VALID = 1
      DONE  = 2
      SET   = 4
      DEL   = 8
    end

    module Err
      # don't use value 0
      OTHER        = 127
      TAG_IN_USE   = 1
      UNKNOWN_VERB = 2
      REDIRECT     = 3
      TOO_LATE     = 4
      CAS_MISMATCH = 5

      # match unix errno
      NOTDIR       = 20
      ISDIR        = 21
      NOINT        = 22
    end

    optional :err_code,   Err,     100
    optional :err_detail, :string, 101
  end

end
