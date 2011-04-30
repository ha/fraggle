require 'rubygems'
require 'fraggle'

EM.run do
  c = Fraggle.connect

  c.rev do |v|
    # Valid
    req = c.getdir_all("/ctl/node", v.rev) do |ents, err|
      if err
        p [:err, err]
      else
        ents.each do |e|
          puts File.join(req.path, e.path)
        end
      end
    end

    # Limit 0 return nothing
    c.getdir_all("/ctl/node", v.rev, 0, 0) do |ents, err|
      p [:ret, ents, err]
    end

    # Error
    c.getdir_all("/nothere", v.rev) do |ents, err|
      p [:ret, ents, err]
    end
  end
end
