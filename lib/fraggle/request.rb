require 'beefcake'
require 'fraggle/msg.pb'
require 'fraggle/emitter'

##
# An extension to Request in msg.rb. I want to keep these seperated so when
# future versions of Beefcake can generate code, we don't have to manually add
# this back in for each generation.

module Fraggle

  class Request
    include Emitter
  end

end
