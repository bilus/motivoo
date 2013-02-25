require_relative 'user_data'

module Motivoo
  
  # Event tracking.
  #
  class Tracker
    
    @@cohorts = {
      "day" => lambda { Date.today.strftime("%Y-%m-%d") },
      "month" => lambda { Date.today.strftime("%Y-%m") },
      "week" => lambda { date = Date.today; "#{date.year}(#{date.cweek})" }
    }
    
    # Returns defined cohorts.
    #
    def self.cohorts
      @@cohorts
    end
    
    # Define a cohort.
    #
    # @example
    #   Tracker.define_cohort("release") { "1.0.2" }
    #
    def self.define_cohort(name, &block)
      raise "Cohort #{name} already defined." if @@cohorts.member?(name)
      @@cohorts[name] = block
    end
    
    # Creates a tracker.
    #
    def initialize(user_data, connection)
      @connection = connection
      @user_data = user_data
    end
    
    HASH_KEY = "motivoo.tracker"
    
    # Injects itself into the hash (used internally to store a Tracker object in Rack env).
    #
    def serialize_into(hash)
      hash.merge(HASH_KEY => self)
    end
    
    # Returns a Tracker instance from the hash (used internally with Rack env).
    #
    def self.deserialize_from(hash)
      hash[HASH_KEY] or raise "Tracker couldn't be found in the hash. Internal error."
    end
    
    # Associates the currently tracked user with an external user.
    # Usually called after login or signup with id of the user in the user's database.
    # This id is not visible in the cookies.
    #
    def set_ext_user_id(ext_user_id)
      @user_data.set_ext_user_id(ext_user_id)
    end

    [:acquisition, :activation, :retention, :referral, :revenue].each do |category| # TODO: Duplication -- Report#acquisitions_by etc.
      
      # Event tracking methods.
      # 
      # @example
      #   tracker.activation(:signup)
      # tracks a signup of the current user.
      #
      define_method(category) do |status, options = {}|
        # puts "#{category.to_s}(#{status.inspect}) -- @user_data = #{@user_data.inspect}"
        allow_repeated = options.delete(:allow_repeated)
        raise "Unrecognized option(s): #{options.keys.join(', ')}." unless options.empty?
        
        begin
          if allow_repeated
            do_track(category, status)
          else
            ensure_track_once(category, status) do
              do_track(category, status)
            end
          end
        rescue => e
          Kernel.puts "Error in Motivoo::Tracker##{category.to_s}: #{e}"
        end
      end
    end
    
    private

    def ensure_track_once(category, status)
      key = "#{category.to_s}##{status.to_s}"
      # puts "ensure_track_once key = #{key.inspect} #{@user_data.inspect}"
      already_tracked = @user_data[key]
      # puts "already_tracked? #{already_tracked.inspect}"
      unless already_tracked
        @user_data[key] = true
        yield
      end
    end
    
    def do_track(category, status)
      user_cohorts = @user_data.cohorts
      Tracker.cohorts.each_pair do |cohort_name, proc|
        assigned_cohort = user_cohorts[cohort_name]
        cohort = assigned_cohort || proc.call

        # TODO: Performance issue, each one is a separate HTTP call to the database server. Calls can be easily combined:
        # @user_data.assign_to(cohort_name1: cohort1, cohort_name2: cohort2 ...)
        # @connection.track(..array...)
        # Arguments to these calls can be easily built using inject instead of each_pair above.
        @user_data.assign_to(cohort_name, cohort) unless assigned_cohort
        @connection.track(category.to_s, status.to_s, cohort_name, cohort)
      end
    end
  end
end