require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do
  c = Fraggle.connect

  paths = []

  req = c.walk("/**", 1)

  valid = Proc.new do |e|
    paths << e.path+"="+e.value
  end

  done = Proc.new do
    puts "rev #{req.rev} " + ("-"*25)
    puts *paths

    paths.clear

    req = c.walk("/**", req.rev+1)
    req.valid(&valid)
    req.done(&done)
  end

  req.valid(&valid)
  req.done(&done)
end
