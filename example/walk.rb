require 'rubygems'
require 'fraggle'

EM.run do
  c = Fraggle.connect

  c.rev do |v|
    # Valid
    req = c.walk(v, "/ctl/node/**") do |ents, err|
      if err
        p [:err, err]
      else
        ents.each do |e|
          puts File.join(req.path, e.path) + "=" + e.value
        end
      end
    end

    # Limit 0 return nothing
    c.walk(v, "/ctl/node/**", 0, 0) do |ents, err|
      p [:nothing, ents, err]
    end

    # Error
    c.walk(v, "/nothere") do |ents, err|
      p [:nothere, ents, err]
    end
  end
end
