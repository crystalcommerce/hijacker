module Hijacker::ControllerMethods
  module Instance
    def hijack_connection
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
      hosted_environments = Hijacker.config[:hosted_environments] || ['staging','production']
      if hosted_environments.include?(Rails.env)
        Hijacker.config[:domain_patterns].find {|pattern| host =~ pattern}
        client = $1
      else # development, test, etc
        client = ActiveRecord::Base.configurations[Rails.env]['database']
      end

      raise Hijacker::UnparseableURL, "cannot parse '#{host}'" if client.nil?
    
      master, sister = Hijacker::Database.find_master_and_sister_for(client)
  
      return [master, sister]
    end
  
    def render_invalid_db
      render :text => "You do not appear to have an account with us (#{request.host})"
    end
  end
end
