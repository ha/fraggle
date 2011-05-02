require 'rubygems'
require 'perftools'
require 'eventmachine'
require 'fraggle'

ENV['CPUPROFILE_FREQUENCY'] = '4000'

reqs = 0
prof = ARGV[0]

def rset(c, count, rev, path, value, &blk)
  c.set(rev, path, value) do |e|
    if count == 0
      blk.call
    end

    rset(c, count-1, e.rev, path, value, &blk)
  end
end

EM.run do
  c = Fraggle.connect

  if prof
    PerfTools::CpuProfiler.start("fraggle-sets.prof")
  end

  c.rev do |v|
    start = Time.now
    rset(c, 100_000, 0, "/sets", "bar") do
      if prof
        PerfTools::CpuProfiler.stop
        `pprof.rb fraggle-sets.prof --gif > fraggle-sets.prof.gif`
      end

      EM.stop_event_loop

      puts "Time: #{Time.now - start}"
    end
  end
end
