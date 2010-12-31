require 'fraggel'

class FraggelTest < Test::Unit::TestCase
  include Fraggel::Encoder

  attr_reader :client, :log

  class FakeFraggel
    include Fraggel

    attr_reader :sent

    ## Expose @callbacks for tests
    attr_reader :callbacks

    def initialize
      @sent = ""
    end

    def send_data(data)
      @sent << data
    end
  end

  def setup
    @log    = []
    @client = FakeFraggel.new

    # Fake a successful connection
    @client.post_init
  end

  def respond(response)
    client.receive_data(encode(response))
  end

  def test_call_sends_data
    client.call :TEST do
      # Do nothing
    end

    assert_equal encode([1, "TEST"]), client.sent
  end

  def test_call_calls_callback
    callback = Proc.new do |x|
      log << x
    end

    opid = client.call :TEST, &callback

    respond [opid, 0, :CALLED]

    # Make sure the callback is called
    assert_equal [:CALLED], log

    # Make sure the callback is held
    assert_equal callback, client.callbacks[opid]
  end

end
