#!/usr/bin/env ruby

# By Mark McGranaghan

require "rubygems"
require "bundler"
Bundler.setup
require "fraggle"
require "statsample"

$stdout.sync = true

abort("read <total> <width> [verbose]") if (ARGV.size < 2)
total = ARGV[0].to_i
width = ARGV[1].to_i
verbose = !!ARGV[2]
latencies = []

EM.run do
  client = Fraggle.connect
  sent = 0
  received = 0
  start = Time.now
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
      client.get(nil, "/processes/#{sent}") do |r|
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
    else
      # pipe closed
    end
    EM.next_tick(&tick)
  end
  tick.call
end
