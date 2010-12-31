module Fraggel

  module Encoder

    class UnknownType < StandardError ; end

    def encode(value)
      case value
      when nil
        "$-1\r\n"
      when true
        encode(1)
      when false
        encode(0)
      when Integer
        ":%d\r\n" % [value]
      when String
        "$%d\r\n%s\r\n" % [value.length, value]
      when Array
        mapped = value.map {|x| encode(x) }
        "*%d\r\n%s" % [mapped.length, mapped]
      when StandardError, Exception
        "-ERR: %s\r\n" % [value.message]
      when Symbol
        "+%s\r\n" % [value]
      else
        raise UnknownType, value
      end
    end

  end

end
