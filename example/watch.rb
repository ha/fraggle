require 'rubygems'
require 'fraggle'

EM.run do
  c = Fraggle.connect

  c.rev do |v|
    c.watch(v, "/ctl/node/**") do |e, err|
      p [e, err]
    end
  end
end
