require 'rubygems'
require 'fraggle'

###
# To see this example in action, run 1 doozerd and attach 2
# more to it before running.
#
# NOTE: If you have the doozerd source, you can run ./bin/test-cluster
#
EM.run do
  c = Fraggle.connect
  c.log.level = Logger::DEBUG

  puts "# To see this work, kill the doozer this is connected to"
  puts "# to see it resend the request to the next connection."
  puts

  # Wait for rev 100,000
  c.get("/foo", 100_000) do |e|
    p ["This should not be!", e]
  end.error do |e|
    p [:err, e]
  end.done do
    p [:done, "This should not be!"]
  end
end
