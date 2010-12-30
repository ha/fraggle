require 'fraggel'

EM.run do
  client = Fraggel.connect 8046

  client.set "/foo", "bar", :missing do |cas, err|
    p [:xrb, "boom!"]
  end
end
