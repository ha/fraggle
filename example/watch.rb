require 'rubygems'
require 'fraggle'

EM.run do
  c = Fraggle.connect do |c, err|
    if err
      fail err.message
    end

    c.rev do |v|
      c.watch(v, "/ctl/node/**") do |e, err|
        p [e, err]
      end
    end
  end
end
