module Fraggle
  module Logger

    DEBUG = 0
    INFO  = 1
    ERROR = 2

    attr_accessor :writer, :level

    def log(lv, msg)
      label = case lv
      when DEBUG then "debug "
      when INFO  then "info  "
      when ERROR then "error "
      end

      if lv >= level
        writer.puts "#{label}: #{msg}"
      end
    end

    def debug(msg) ; log(DEBUG, msg) ; end
    def info(msg)  ; log(INFO,  msg) ; end
    def error(msg) ; log(ERROR, msg) ; end
  end
end
