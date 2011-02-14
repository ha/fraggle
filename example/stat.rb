require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do

  EM.error_handler do |e|
    $stderr.puts e.message + "\n" + (e.backtrace * "\n")
  end

  c = Fraggle.connect

  EM.add_periodic_timer(1) do
    c.stat "/example" do |e|
      p e
    end
  end

  EM.add_periodic_timer(0.5) do
    c.set "/example/#{rand(10)}", "test", :clobber
  end

end
