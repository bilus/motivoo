require_relative 'tracker'

module Motivoo
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
  
  # Define a cohort.
  #
  def define_cohort(cohort_name, &block)
    Tracker.define_cohort(cohort_name, &block)
  end
end

Motivoo.configure {}
