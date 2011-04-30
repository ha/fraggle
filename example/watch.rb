require 'rubygems'
require 'fraggle'

EM.run do
  c = Fraggle.connect

  c.rev do |v|
    c.watch("/ctl/node/**", v.rev) do |e|
      p e
    end
  end
end
