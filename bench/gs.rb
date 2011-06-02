#!/usr/bin/env ruby

# By Mark McGranaghan

require "rubygems"
require "bundler"
Bundler.setup
require "fraggle"
require "statsample"

$stdout.sync = true

abort("gs <[get|set]> <total> <width> [verbose]") if (ARGV.size < 2)
op = ARGV.shift.to_sym
total = ARGV.shift.to_i
width = ARGV.shift.to_i
verbose = !!ARGV.shift
latencies = []
sent_at = nil

EM.run do
  Fraggle.connect do |c, err|
    if err
      raise err.message
    end

    sent = 0
    received = 0
    start = Time.now

    f = Proc.new do |r, err|
      if err
        p [:err, err]
        next
      end

      received_at = Time.now
      received +=1
      latency = received_at - sent_at

      latencies << latency
      if verbose
        $stdout.puts("received=#{received} ok=#{r.ok?} rev=#{r.rev} latency=#{latency}")
      elsif (received % 10 == 0)
        $stdout.print(".")
      end
      if (received == total)
        EM.stop
        elapsed = Time.now - start
        vector = latencies.to_scale
        $stdout.puts
        $stdout.puts("total=#{total}")
        $stdout.puts("elapsed=#{elapsed}")
        $stdout.puts("rate=#{total / elapsed}")
        $stdout.puts("mean=#{vector.mean}")
        $stdout.puts("sd=#{vector.sd}")
        $stdout.puts("perc90=#{vector.percentil(90)}")
        $stdout.puts("perc99=#{vector.percentil(99)}")
        $stdout.puts("max=#{vector.max}")
      end
    end

    tick = Proc.new do
      if (sent == total)
        # done sending
      elsif ((sent - received) < width)
        # pipe open
        sent_at = Time.now
        sent += 1
        if verbose
          $stdout.puts("sent=#{sent}")
        end

        case op
        when :get
          c.get(nil, "/processes/#{sent}", &f)
        when :set
          c.set(Fraggle::Clobber, "/processes/#{sent}", "1", &f)
        end
      else
        # pipe closed
      end
      EM.next_tick(&tick)
    end
    tick.call
  end
end
