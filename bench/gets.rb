require 'rubygems'
require 'perftools'
require 'eventmachine'
require 'fraggle'

ENV['CPUPROFILE_FREQUENCY'] = '4000'

reqs = 0
prof = ARGV[0]

def rget(c, count, rev, path, &blk)
  c.get(rev, path) do |e|
    if count == 0
      blk.call
    end

    rget(c, count-1, rev, path, &blk)
  end
end

EM.run do
  c = Fraggle.connect

  if prof
    PerfTools::CpuProfiler.start("fraggle-gets.prof")
  end

  c.rev do |v|
    start = Time.now
    rget(c, 100_000, v.rev, "/ctl/cal/0") do
      if prof
        PerfTools::CpuProfiler.stop
        `pprof.rb fraggle-gets.prof --gif > fraggle-gets.prof.gif`
      end

      EM.stop_event_loop

      puts "Time: #{Time.now - start}"
    end
  end
end
