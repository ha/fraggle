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


  ##
  # call
  #
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

  ##
  # GET
  #
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

  ##
  # SET
  #
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

  ##
  # SETT
  #
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

  ##
  # CLOSE
  #
  def test_close_call
    client.close(99) {}
    expected = [
      [:CLOSE, 99]
    ]
    assert_equal expected, client.called
  end

  def test_close
    opid = client.close 99 do |err|
      @response = err
    end

    respond [opid, Fraggel::Valid | Fraggel::Done, :OK]
    assert_nil response
  end

  def test_close_error
    opid = client.close 99 do |err|
      @response = err
    end

    respond [opid, Fraggel::Valid | Fraggel::Done, StandardError.new("test")]
    assert_equal StandardError, response.class
    assert_equal "ERR: test", response.message
  end

  ##
  # DEL
  #
  def test_del_call
    client.del("/foo", "68") {}
    expected = [
      [:DEL, ["/foo", "68"]]
    ]
    assert_equal expected, client.called
  end

  def test_del
    opid = client.del "/foo", "68" do |err|
      @response = err
    end

    respond [opid, Fraggel::Valid | Fraggel::Done, :OK]
    assert_nil response
  end

  def test_del_error
    opid = client.del "/foo", "123" do |err|
      @response = err
    end

    respond [opid, Fraggel::Valid | Fraggel::Done, StandardError.new("test")]
    assert_equal StandardError, response.class
    assert_equal "ERR: test", response.message
  end

  ##
  # NOOP
  #
  def test_noop_call
    client.noop() {}
    expected = [
      [:NOOP]
    ]
    assert_equal expected, client.called
  end

  def test_noop
    opid = client.noop do |err|
      @response = err
    end

    respond [opid, Fraggel::Valid | Fraggel::Done, :OK]
    assert_nil response
  end

  def test_noop_error
    opid = client.noop do |err|
      @response = err
    end

    respond [opid, Fraggel::Valid | Fraggel::Done, StandardError.new("test")]
    assert_equal StandardError, response.class
    assert_equal "ERR: test", response.message
  end

  ##
  # SNAP
  #
  def test_snap_call
    client.snap() {}
    expected = [
      [:SNAP]
    ]
    assert_equal expected, client.called
  end

  def test_snap
    opid = client.snap do |sid, err|
      @response = [sid, err]
    end

    respond [opid, Fraggel::Valid | Fraggel::Done, 123]
    sid, err = response

    assert_nil err
    assert_equal 123, sid
  end

  def test_snap_error
    opid = client.snap do |sid, err|
      @response = [sid, err]
    end

    respond [opid, Fraggel::Valid | Fraggel::Done, StandardError.new("test")]
    sid, err = response

    assert_equal StandardError, err.class
    assert_equal "ERR: test", err.message
    assert_nil sid
  end

  ##
  # DELSNAP
  #
  def test_delsnap_call
    client.delsnap() {}
    expected = [
      [:DELSNAP]
    ]
    assert_equal expected, client.called
  end

  def test_delsnap
    opid = client.delsnap do |err|
      @response = err
    end

    respond [opid, Fraggel::Valid | Fraggel::Done, 123]
    sid, err = response

    assert_nil err
  end

  def test_delsnap_error
    opid = client.delsnap do |err|
      @response = err
    end

    respond [opid, Fraggel::Valid | Fraggel::Done, StandardError.new("test")]
    sid, err = response

    assert_equal StandardError, err.class
    assert_equal "ERR: test", err.message
  end

  ##
  # WALK
  #
  def test_walk_call
    client.walk("/test/**") {}
    client.walk("/test/*", 123) {}
    expected = [
      [:WALK, ["/test/**", 0]],
      [:WALK, ["/test/*", 123]],
    ]
    assert_equal expected, client.called
  end

  def test_walk
    opid = client.walk "/test/**" do |path, body, cas, err|
      @response = [path, body, cas, err]
    end

    respond [opid, Fraggel::Valid, ["/test/a", "1", "99"]]
    path, body, cas, err = response

    assert_nil   err
    assert_equal "/test/a", path
    assert_equal "1", body
    assert_equal "99", cas
    assert ! cas.dir?

    respond [opid, Fraggel::Valid, ["/test/b", "2", "123"]]
    path, body, cas, err = response

    assert_nil   err
    assert_equal "/test/b", path
    assert_equal "2", body
    assert_equal "123", cas
    assert ! cas.dir?

    respond [opid, Fraggel::Done]
    path, body, cas, err = response

    assert_equal :done, err
    assert_nil path
    assert_nil body
    assert_nil cas
  end

  def test_walk_error
    opid = client.walk "/test/**" do |path, body, cas, err|
      @response = [path, body, cas, err]
    end

    respond [opid, Fraggel::Valid, StandardError.new("test")]
    path, body, cas, err = response

    assert_equal StandardError, err.class
    assert_equal "ERR: test", err.message
    assert_nil path
    assert_nil body
    assert_nil cas
  end

  ##
  # WATCH
  #
  def test_watch_call
    client.watch("/test/**") {}
    expected = [
      [:WATCH, "/test/**"],
    ]
    assert_equal expected, client.called
  end

  def test_watch
    opid = client.watch "/test/**" do |path, body, cas, err|
      @response = [path, body, cas, err]
    end

    respond [opid, Fraggel::Valid, ["/test/a", "1", "99"]]
    path, body, cas, err = response

    assert_nil   err
    assert_equal "/test/a", path
    assert_equal "1", body
    assert_equal "99", cas
    assert ! cas.dir?

    respond [opid, Fraggel::Valid, ["/test/b", "2", "123"]]
    path, body, cas, err = response

    assert_nil   err
    assert_equal "/test/b", path
    assert_equal "2", body
    assert_equal "123", cas
    assert ! cas.dir?

    respond [opid, Fraggel::Done]
    path, body, cas, err = response

    assert_equal :done, err
    assert_nil path
    assert_nil body
    assert_nil cas
  end

  def test_watch_error
    opid = client.watch "/test/**" do |path, body, cas, err|
      @response = [path, body, cas, err]
    end

    respond [opid, Fraggel::Valid, StandardError.new("test")]
    path, body, cas, err = response

    assert_equal StandardError, err.class
    assert_equal "ERR: test", err.message
    assert_nil path
    assert_nil body
    assert_nil cas
  end

end
