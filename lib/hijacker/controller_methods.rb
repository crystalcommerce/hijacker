module Hijacker::ControllerMethods
  module Class
    def hijack_connection(options = {})
      defaults = {
        :domain_patterns => [],
        :sister_site_models => []
      }
      Hijacker.config = defaults.merge(options)

      self.before_filter :hijack_db_filter
    end
  end

  module Instance
    def hijack_db_filter
      host = request.host
  
      master, sister = determine_databases(host)

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
    def determine_databases(host)
      client = Hijacker.config[:static_routes].call if Hijacker.config[:static_routes]
    
      Hijacker.config[:domain_patterns].find {|pattern| host =~ pattern}
      client ||= $1
      raise Hijacker::UnparseableURL if client.nil?
    
      master = Hijacker::Database.find_master_for(client)
      sister = master.nil? ? nil : client
      master ||= client
  
      return [master, sister]
    end
  
    def render_invalid_db
      render :text => "You do not appear to have an account with us (#{reqest.host})"
    end
  end
end
