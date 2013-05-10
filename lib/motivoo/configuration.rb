require_relative 'tracker'

module Motivoo
  
  # Configurable settings.
  #
  class Configuration
    attr_accessor :mongo_host
    attr_accessor :mongo_db
    attr_accessor :mongo_port
    attr_accessor :mongo_user
    attr_accessor :mongo_password
    
    def initialize
      @mongo_host = "localhost"
      @mongo_db = "motivoo"
    end

    def reset!
      @mongo_host = nil
      @mongo_db = nil
      @mongo_port = nil
      @mongo_user = nil
      @mongo_password = nil
    end
    
    def method_missing(meth, *args, &block)
      if meth.to_s =~ /^(before_.+)$/ || meth.to_s =~ /^(after_.+)$/ || meth.to_s =~ /^(on_.+)$/
        Tracker.send($1.to_sym, *args, &block)
      else
        super
      end
    end
  
    def respond_to?(meth)
      if meth.to_s =~ /^(before_.+)$/ || meth.to_s =~ /^(after_.+)$/ || meth.to_s =~ /^(on_.+)$/
        true
      else
        super
      end
    end
    
    # Define a cohort.
    #
    def define_cohort(cohort_name, &block)
      Tracker.define_cohort(cohort_name, &block)
    end
  end
end

module Motivoo
  extend self
  attr_accessor :configuration
  
  # Call this method to modify defaults in your initializers.
  #
  def configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end
end

Motivoo.configure {}
