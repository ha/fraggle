module Fraggle

  def self.uri(u)
    if u =~ /^doozerd:\?(.*)$/
      parts = $1.split("&")
      parts.inject([]) do |m, pt|
        k, v = pt.split("=")
        if k == "ca"
          m << v
        end
        m
      end
    else
      raise ArgumentError, "invalid doozerd uri"
    end
  end

end
