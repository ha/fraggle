module Fraggle
  module Logger

    DEBUG = 0
    INFO  = 1
    WARN  = 2
    ERROR = 3

    attr_writer :writer, :level

    def log(lv, msg)
      label = case lv
      when DEBUG then "debug "
      when INFO  then "info  "
      when WARN  then "warn  "
      when ERROR then "error "
      end

      if lv >= level
        writer.puts "#{label}: #{msg}"
      end
    end

    def writer ; @writer ||= STDERR ; end
    def level  ; @level ||= WARN   ; end

    def debug(msg) ; log(DEBUG, msg) ; end
    def info(msg)  ; log(INFO,  msg) ; end
    def warn(msg)  ; log(WARN,  msg) ; end
    def error(msg) ; log(ERROR, msg) ; end
  end
end
