require 'rubygems'
require 'fraggle'

EM.run do
  c = Fraggle.connect

  c.rev do |v|
    # Valid
    req = c.walk_all("/ctl/node/**", v.rev) do |ents, err|
      if err
        p [:err, err]
      else
        ents.each do |e|
          puts File.join(req.path, e.path) + "=" + e.value
        end
      end
    end

    # Limit 0 return nothing
    c.walk_all("/ctl/node/**", v.rev, 0, 0) do |ents, err|
      p [:ret, ents, err]
    end

    # Error
    c.walk_all("/nothere", v.rev) do |ents, err|
      p [:ret, ents, err]
    end
  end
end
