module ActiveRecord
  module ConnectionAdapters
    if defined?(MysqlAdapter)
      class MysqlAdapter
        attr_accessor :config
      end
    end

    if defined?(Mysql2Adapter)
      class Mysql2Adapter
        attr_accessor :config
      end
    end
  end
end
  
