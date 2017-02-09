module RedisKeysModule
  extend Hijacker::RedisKeys

  module Helper
    def method_missing(method_sym, *arguments, &block)
      if RedisKeysModule.methods.include? method_sym
        inputs = nil
        if(arguments.length > 0)
          inputs = [method_sym].concat(arguments)
        else
          inputs = [method_sym]
        end

        if block
          RedisKeysModule.send(*inputs, &block)
        else
          RedisKeysModule.send(*inputs)
        end
      else
        super
      end
    end
  end
end

