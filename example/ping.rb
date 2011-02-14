require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do

  EM.error_handler do |e|
    $stderr.puts e.message + "\n" + (e.backtrace * "\n")
  end

  c = Fraggle.connect

  EM.add_periodic_timer(1) do
    c.get "/ping" do |e|
      p [:e, e]
    end
  end

end
