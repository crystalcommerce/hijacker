# DEPRECATED: use middleware instead
module Hijacker::ControllerMethods
  module Instance
    def hijack_connection
      master, sister = determine_databases

      Hijacker.connect(master, sister)

      return true
    rescue Hijacker::InvalidDatabase => e
      render_invalid_db

      # If we've encountered a bad database connection, we don't want
      # to continue rendering the rest of the before_filters on this, which it will
      # try to do even when just rendering the bit of text above. If any filters
      # return false, though, it will halt the filter chain.
      return false
    end

    # Returns 2-member array of the main database to connect to, and the sister
    # (sister will be nil if no master is found, which means we are on the master).
    def determine_databases
      Hijacker::RequestParser.from_request(request).determine_databases
    end

    def render_invalid_db
      render :text => "You do not appear to have an account with us (#{request.host})",
        :status => 404
    end
  end
end

class ActionController::Base
  include Hijacker::ControllerMethods::Instance
end
