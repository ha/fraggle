require 'fraggle/snap'

module Fraggle

  def self.connect(uri)
    uri = URI(uri)
    c = EM.connect(uri.host, uri.port, Client)
    Snap.new(0, c)
  end

end
