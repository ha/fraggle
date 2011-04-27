require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do

  ## NOTE:  This will be easier the very near future.

  ## Collects names in a directory

  c = Fraggle.connect
  c.log.level = Logger::DEBUG

  def c.getdirx(path, rev, offset, &blk)
    w = Request.new
    w.valid(&blk)

    err = Proc.new do |e|
      if e.err_code == Fraggle::Response::Err::AGAIN
        w.emit(:done)
      else
        w.emit(:error, e)
      end
    end

    req = getdir(path, rev, offset) do |e|
      blk.call(e)
      req = getdirx(path, rev, offset+1, &blk)
      req.error(&err)
    end
    req.error(&err)

    w
  end

  ents, n = [], 0

  f = Proc.new do |e|
    ents << e.path
    n += 1
    c.getdir("/ctl", nil, n, &f).error do |e|
      if e.err_code == Fraggle::Response::Err::RANGE
        p [:ents, ents]
      else
        p [:err, e]
      end
    end
  end

  c.getdir("/ctl", nil, n, &f).error do |e|
    if e.err_code == Fraggle::Response::Err::RANGE
      p [:ents, ents]
    else
      p [:err, e]
    end
  end

end
