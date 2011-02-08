require 'fraggle/snap'
require 'uri'

module Fraggle

  def self.connect(uri, *args)
    uri = URI(uri)
    c = EM.connect(uri.host, uri.port, Client, uri, *args)
    Snap.new(0, c)
  end

end
