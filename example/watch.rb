require 'rubygems'
require 'fraggle'

EM.run do
  c = Fraggle.connect

  c.rev do |v|
    c.watch(v.rev, "/ctl/node/**") do |e|
      p e
    end
  end
end
