class Object
  def metaclass
    (class << self ; self ; end)
  end

  def metadef(name, &blk)
    metaclass.__send__(:define_method, name, &blk)
  end
end
