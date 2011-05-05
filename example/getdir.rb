require 'rubygems'
require 'fraggle'

EM.run do
  c = Fraggle.connect

  c.rev do |v|
    # Valid
    req = c.getdir(v, "/ctl/node") do |ents, err|
      if err
        p [:err, err]
      else
        ents.each do |e|
          puts File.join(req.path, e.path)
        end
      end
    end

    # Limit 0 return nothing
    c.getdir(v, "/ctl/node", 0, 0) do |ents, err|
      p [:ret, ents, err]
    end

    # Error
    c.getdir(v, "/nothere") do |ents, err|
      p [:ret, ents, err]
    end
  end
end
