
require 'rspec'
require 'fraggle/connection'

class TestConnection
 include Fraggle::Connection
 def initialize
 end 
end

describe Fraggle::Connection, '#receive_data' do
  it "should receive data and call received_data (one packet)" do
    msg = "abc123" * 1000
    buf = [msg.size].pack("N") + msg
    res = "done"
    Fraggle::Response.should_receive(:decode).with(msg).and_return(res)
    conn = TestConnection.new
    conn.should_receive(:receive_response).with(res).and_return
    conn.receive_data(buf)
  end
  it "should receive data and call received_data when split across two chunks" do
    msg = "abc" * 100
    buf = [msg.size].pack("N") + msg
    chunks = [
      buf[0..99],
      buf[100..199],
      buf[200..-1]
    ]
    res = "done"
    Fraggle::Response.should_receive(:decode).with(msg).and_return(res)
    conn = TestConnection.new
    conn.should_receive(:receive_response).with(res).and_return
    chunks.each do |chunk|
      conn.receive_data(chunk)
    end
  end
end

