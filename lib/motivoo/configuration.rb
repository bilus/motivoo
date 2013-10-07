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

    attr_accessor :bot_protect_js
    attr_accessor :bot_protect_path
    attr_accessor :bot_protect_js_path
    
    def initialize
      reset!
    end

    def reset!
      @mongo_host = "localhost"
      @mongo_db = "motivoo"
      @mongo_port = nil
      @mongo_user = nil
      @mongo_password = nil
      @bot_protect_js = nil
      @bot_protect_path = "/motivoo/"
      @bot_protect_js_path = "/motivoo/m.js"
      @callbacks = {}
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
    
    def disable_tracking(&block)
      @callbacks ||= {}
      disable_tracking = (@callbacks[:disable_tracking] ||= [])
      disable_tracking << block
    end
    
    def disable_tracking?(env)
      @callbacks ||= {}
      (@callbacks[:disable_tracking] || []).any? {|callback| callback.call(env)}
    end
    
    # Define a cohort.
    #
    def define_cohort(cohort_category, &block)
      Tracker.define_cohort(cohort_category, &block)
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
