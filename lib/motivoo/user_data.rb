require 'rack/request'

module Motivoo
  class UserData
    USER_ID_COOKIE = "motivoo.user_id"
    
    def self.deserialize_from(env, connection)
      user_id, user_data = 
        if (existing_user_id = Rack::Request.new(env).cookies[USER_ID_COOKIE])
          [existing_user_id, connection.find_or_create_user_data(existing_user_id)]
        else
          [connection.generate_user_id, {}]
        end
      UserData.new(user_id, user_data, connection)
    end
    
    def serialize_into(response)
      response.set_cookie(USER_ID_COOKIE, @user_id)
    end

    def initialize(user_id, hash, connection)
      @user_id = user_id
      @cohorts = hash["cohorts"] || {}
      @connection = connection
    end
    
    def assign_to(cohort_name, cohort)
      @connection.assign_cohort(@user_id, cohort_name, cohort)
      @cohorts.store(cohort_name, cohort)
    end
    
    def cohorts
      @cohorts
    end
    
    def set_ext_user_id(ext_user_id)
      user_id, user_data = @connection.find_user_data_by_ext_user_id(ext_user_id)
      if user_id
        @connection.destroy_user_data(@user_id)
        @user_id = user_id
        @cohorts = user_data["cohorts"] || {}
      else
        @connection.set_user_data(@user_id, "ext_user_id" => ext_user_id)
      end
    end
    
    def [](key)
      # TODO: Cache it?
      @connection.get_user_data(@user_id, key)
    end
    
    def []=(key, value)
      # TODO ext_user_id can be set directly by the user bypassing code in UserData#set_ext_user_id
      @connection.set_user_data(@user_id, key => value)
    end
    
    # Testing
    
    def inspect
      "{UserData cohorts=#{@cohorts.inspect} user_id=#{@user_id.inspect}}"
    end
  end
end