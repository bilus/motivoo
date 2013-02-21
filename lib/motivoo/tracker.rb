require_relative 'user_data'

module Motivoo
  class Tracker
    
    DEFAULT_COHORTS = {
      "day" => lambda { Date.today.strftime("%Y-%m-%d") },
      "month" => lambda { Date.today.strftime("%Y-%m") },
      "week" => lambda { date = Date.today; "#{date.year}(#{date.cweek})" }
    }
    
    def initialize(user_data, connection)
      @connection = connection
      @user_data = user_data
    end
    
    HASH_KEY = "motivoo.tracker"
    
    def serialize_into(hash)
      hash.merge(HASH_KEY => self)
    end
    
    def self.deserialize_from(hash)
      hash[HASH_KEY] or raise "Tracker couldn't be found in the hash. Internal error."
    end
    
    def set_ext_user_id(ext_user_id)
      @user_data.set_ext_user_id(ext_user_id)
    end

    [:acquisition, :activation, :retention, :referral, :revenue].each do |category|
      define_method(category) do |status, options = {}|
        allow_repeated = options.delete(:allow_repeated)
        raise "Unrecognized option(s): #{options.keys.join(', ')}." unless options.empty?
        
        if allow_repeated
          do_track(category, status)
        else
          ensure_track_once(category, status) do
            do_track(category, status)
          end
        end
      end
    end
    
    private

    def ensure_track_once(category, status)
      key = "#{category.to_s}_#{status.to_s}"
      already_tracked = @user_data[key]

      unless already_tracked
        @user_data[key] = true
        yield
      end
    end
    
    def do_track(category, status)
      user_cohorts = @user_data.cohorts
      DEFAULT_COHORTS.each_pair do |cohort_name, proc|
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