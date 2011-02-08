require 'fraggle/snap'
require 'uri'

module Fraggle

  def self.connect(uri)
    uri = URI(uri)
    c = EM.connect(uri.host, uri.port, Client, uri)
    Snap.new(0, c)
  end

end
