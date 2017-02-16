module Hijacker

  MYSQL_UNRESPONSIVE_HOST = :unresponsive_host
  MYSQL_UNKNOWN_HOST = :unknown_host
  MYSQL_ACCESS_DENIED = :access_denied
  MYSQL_GENERIC = :generic

  module MysqlErrors
    # Different kinds of Mysql2::Error
    #
    # Mysql2::Error: Can't connect to MySQL server on '169.44.133.61' (111)
    # Mysql2::Error: Unknown MySQL server host 'asdf' (0)
    # Mysql2::Error: Access denied for user 'xcrystal'@'169.44.133.34' (using password: YES)
    # Mysql2::Error: Access denied for user 'crystal'@'169.44.133.34' (using password: YES)
    #
    RE_UNRESPONSIVE_HOST = /Can't connect to MySQL server on '([^']+)'/
    RE_UNKNOWN_HOST = /Unknown MySQL server host '([^']+)'/
    RE_ACCESS_DENIED = /Access denied for user '([^']+)/

    def mysql_error(e)
      error_type = if e.message.match(Hijacker::MysqlErrors::RE_UNRESPONSIVE_HOST)
        MYSQL_UNRESPONSIVE_HOST
      elsif e.message.match(Hijacker::MysqlErrors::RE_UNKNOWN_HOST)
        MYSQL_UNKNOWN_HOST
      elsif e.message.match(Hijacker::MysqlErrors::RE_ACCESS_DENIED)
        MYSQL_ACCESS_DENIED
      else
        MYSQL_GENERIC
      end

      logger.debug "error discovered; #{error_type}"
      error_type
    end

    def mysql_error_is?(e, value)
      (mysql_error(e) == value)
    end
  end
end
