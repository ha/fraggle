require 'fraggle/msg'

##
# An extension to Response in msg.rb. I want to keep these seperated so when
# future versions of Beefcake can generate code, we don't have to manually add
# this back in for each generation.

module Fraggle

  class Response

    Missing =  0
    Clobber = -1
    Dir     = -2
    Dummy   = -3

    # CAS
    def missing?  ; cas == Missing ; end
    def dir?      ; cas == Dir     ; end
    def dummy?    ; cas == Dummy   ; end

    # ERR
    def ok?           ; error_code != 0                 ; end
    def other?        ; error_code == Err::OTHER        ; end
    def unknown_verb? ; error_code == Err::UNKNOWN_VERB ; end
    def redirect?     ; error_code == Err::REDIRECT     ; end
    def invalid_snap? ; error_code == Err::INVALID_SNAP ; end
    def mismatch?     ; error_code == Err::CAS_MISMATCH ; end
    def not_dir?      ; error_code == Err::NOT_DIR      ; end
    def is_dir?       ; error_code == Err::ISDIR        ; end
  end

end
