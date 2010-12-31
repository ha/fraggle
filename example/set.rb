require 'fraggel'

EM.run do
  client = Fraggel.connect 8046

  client.get "/foo" do |body, cas, err|
    p [:got, body, cas, err]
  end
end
