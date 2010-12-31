require 'fraggel'

EM.run do
  client = Fraggel.connect 8046

  client.call :SET, ["/foo", "bar", "0"] do |res|
    p [:xrb, res]
  end
end
