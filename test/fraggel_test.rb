require 'fraggel'

class FraggelTest < Test::Unit::TestCase
  include Fraggel::Encoder

  attr_reader :client, :response

  class FakeFraggel
    include Fraggel

    attr_reader :sent, :called

    ## Expose @callbacks for tests
    attr_reader :callbacks

    def initialize
      @sent   = ""
      @called = []
    end

    def call(*args)
      @called << args
      super(*args)
    end

    def send_data(data)
      @sent << data
    end
  end

  def setup
    @response = []
    @client   = FakeFraggel.new

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
    opid = client.call :TEST do |x|
      @response = x
    end

    respond [opid, Fraggel::Valid, :CALLED]

    # Make sure the callback is called
    assert_equal :CALLED, response
  end

  def test_call_holds_undone_callback
    callback = Proc.new do |x|
      # Do nothing
    end

    opid = client.call :TEST, &callback

    respond [opid, Fraggel::Valid, :CALLED]

    # Make sure the callback is held
    assert_equal callback, client.callbacks[opid]
  end

  def test_done
    @response = []
    opid = client.call :TEST do |err|
      @response << err
    end

    respond [opid, Fraggel::Done]

    assert_equal [:done], response
    assert_nil client.callbacks[opid]
  end

  def test_valid_and_done
    @response = []
    opid = client.call :TEST do |err|
      @response << err
    end

    respond [opid, Fraggel::Valid | Fraggel::Done]

    assert_equal [nil, :done], response
    assert_nil client.callbacks[opid]
  end

  def test_get_call
    client.get("/ping") {}
    client.get("/ping", 123) {}
    expected = [
      [:GET, ["/ping", 0]],
      [:GET, ["/ping", 123]],
    ]
    assert_equal expected, client.called
  end

  def test_get_entry
    opid = client.get "/ping" do |body, cas, err|
      @response = [body, cas, err]
    end

    respond [opid, Fraggel::Valid | Fraggel::Done, [["pong"], "99"]]
    body, cas, err = response

    assert_nil   err
    assert_equal ["pong"], body
    assert_equal "99", cas
    assert ! cas.dir?
  end

  def test_get_error
    opid = client.get "/ping" do |body, cas, err|
      @response = [body, cas, err]
    end

    respond [opid, Fraggel::Valid, StandardError.new("test")]
    body, cas, err = response

    assert_nil body
    assert_nil cas
    assert_equal StandardError, err.class
    assert_equal "ERR: test", err.message
  end

  def test_get_directory
    opid = client.get "/letters" do |body, cas, err|
      @response = [body, cas, err]
    end

    entries = ["a", "b", "c"]
    respond [opid, Fraggel::Valid | Fraggel::Done, [entries, Fraggel::Dir]]
    body, cas, err = response

    assert_nil err
    assert_equal entries, body
    assert_equal Fraggel::Dir, cas
    assert cas.dir?
  end

  def test_set_call
    client.set("/foo", "bar", "99") {}
    client.set("/foo", "bar", :missing) {}
    client.set("/foo", "bar", :clobber) {}
    expected = [
      [:SET, ["/foo", "bar", "99"]],
      [:SET, ["/foo", "bar", "0"]],
      [:SET, ["/foo", "bar", ""]]
    ]
    assert_equal expected, client.called
  end

  def test_set
    opid = client.set "/letters/a", "1", "99" do |cas, err|
      @response = [cas, err]
    end

    respond [opid, Fraggel::Valid | Fraggel::Done, "99"]
    cas, err = response

    # Check err and body
    assert_nil err
    assert_equal "99", cas
    assert ! cas.dir?
  end

  def test_set_error
    opid = client.set "/letters/a", "1", "99" do |cas, err|
      @response = [cas, err]
    end

    respond [opid, Fraggel::Valid | Fraggel::Done, StandardError.new("cas mismatch")]
    cas, err = response

    assert_equal StandardError, err.class
    assert_equal "ERR: cas mismatch", err.message
    assert_nil cas
  end

  def test_sett_call
    client.sett("/foo", 100, "99") {}
    client.sett("/foo", 100, :missing) {}
    client.sett("/foo", 100, :clobber) {}
    expected = [
      [:SETT, ["/foo", 100, "99"]],
      [:SETT, ["/foo", 100, "0"]],
      [:SETT, ["/foo", 100, ""]]
    ]
    assert_equal expected, client.called
  end

  def test_sett
    opid = client.sett "/timer/a", 100, "99" do |t, cas, err|
      @response = [t, cas, err]
    end

    respond [opid, Fraggel::Valid | Fraggel::Done, [1000, "99"]]
    t, cas, err = response

    assert_nil err
    assert_equal 1000, t
    assert_equal "99", cas
    assert ! cas.dir?
  end

  def test_sett_error
    opid = client.sett "/timer/a", 100, "99" do |t, cas, err|
      @response = [t, cas, err]
    end

    respond [opid, Fraggel::Valid | Fraggel::Done, StandardError.new("test")]
    t, cas, err = response

    assert_equal StandardError, err.class
    assert_equal "ERR: test", err.message
    assert_nil t
    assert_nil cas
  end

end
