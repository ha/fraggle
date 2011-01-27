require 'beefcake'

module Fraggle

  class Request
    include Beefcake::Message

    required :tag, :int32, 1

    module Verb
      CHECKIN  = 0;  # cas, id          => cas
      GET      = 1;  # path, id         => cas, value
      SET      = 2;  # cas, path, value => cas
      DEL      = 3;  # cas, path        => {}
      ESET     = 4;  # cas, path        => {}
      SNAP     = 5;  # {}               => seqn, id
      DELSNAP  = 6;  # id               => {}
      NOOP     = 7;  # {}               => {}
      WATCH    = 8;  # path             => {cas, path, value}+
      CANCEL   = 10; # id               => {}

      # future
      GETDIR   = 14; # path             => {cas, value}+
      MONITOR  = 11; # path             => {cas, path, value}+
      SYNCPATH = 12; # path             => cas, value
      WALK     = 9;  # path, id         => {cas, path, value}+

      # deprecated
      JOIN     = 13;
    end

    required :verb, Verb, 2

    optional :cas,   :int64,  3
    optional :path,  :string, 4
    optional :value, :bytes,  5
    optional :id,    :int32,  6

    optional :offset, :int32, 7
    optional :limit,  :int32, 8

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

    module Flag
      VALID = 1
      DONE  = 2
    end

    module Err
      # don't use value 0
      OTHER        = 127
      TAG_IN_USE   = 1
      UNKNOWN_VERB = 2
      REDIRECT     = 3
      INVALID_SNAP = 4
      CAS_MISMATCH = 5

      # match unix errno
      NOTDIR       = 20
      ISDIR        = 21
    end

    optional :err_code,   Err,     100
    optional :err_detail, :string, 101
  end

end
