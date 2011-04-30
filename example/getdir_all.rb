require 'rubygems'
require 'fraggle'

EM.run do
  c = Fraggle.connect
  req = c.getdir_all("/ctl/nde") do |ents, err|
    if err
      p [:err, err]
    else
      ents.each do |e|
        puts File.join(req.path, e.path)
      end
    end
  end

  c.getdir_all("/ctl/node", 0, 0) do |ents, err|
    p [:ret, ents, err]
  end
end
