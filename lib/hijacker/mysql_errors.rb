module Hijacker

  class UnparseableURL < StandardError; end
  class InvalidDatabase < StandardError
    attr_reader :database
    def initialize(database, message = "Database #{database} not found")
      @database = database
      super(message)
    end
  end
  
  class GenericDbError < StandardError; end
  class UnknownHostError < GenericDbError; end
  class AccessDeniedError < GenericDbError; end
  
  MYSQL_UNRESPONSIVE_HOST = UnresponsiveHostError
  MYSQL_UNKNOWN_HOST = UnknownHostError
  MYSQL_UNKNOWN_DB = InvalidDatabase
  MYSQL_ACCESS_DENIED = AccessDeniedError
  MYSQL_GENERIC = GenericDbError

  module MysqlErrors
    # Different kinds of Mysql2::Error
    #
    # Mysql2::Error: Can't connect to MySQL server on '169.44.133.61' (111)
    # Mysql2::Error: Unknown MySQL server host 'asdf' (0)
    # Mysql2::Error: Access denied for user 'xcrystal'@'169.44.133.34' (using password: YES)
    # Mysql2::Error: Access denied for user 'crystal'@'169.44.133.34' (using password: YES)
    # Mysql2::Error: Unknown database 'mtgcards'
    #
    RE_UNRESPONSIVE_HOST = /Can't connect to MySQL server on '([^']+)'/
    RE_UNKNOWN_HOST = /Unknown MySQL server host '([^']+)'/
    RE_UNKNOWN_DB = /Unknown database '([^']+)'/
    RE_ACCESS_DENIED = /Access denied for user '([^']+)/

    def mysql_error(e)
      error_class = if e.message.match(Hijacker::MysqlErrors::RE_UNRESPONSIVE_HOST)
        MYSQL_UNRESPONSIVE_HOST
      elsif e.message.match(Hijacker::MysqlErrors::RE_UNKNOWN_HOST)
        MYSQL_UNKNOWN_HOST
      elsif e.message.match(Hijacker::MysqlErrors::RE_UNKNOWN_DB)
        MYSQL_UNKNOWN_DB
      elsif e.message.match(Hijacker::MysqlErrors::RE_ACCESS_DENIED)
        MYSQL_ACCESS_DENIED
      else
        MYSQL_GENERIC
      end

      logger.warn "[Hijacker::MysqlErrors] error discovered; #{error_class.name}, #{e.message}"
      error_class
    end

    def mysql_error_is?(e, klass)
      (mysql_error(e) == klass)
    end
  end
end
