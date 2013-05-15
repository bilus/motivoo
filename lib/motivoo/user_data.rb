require 'rack/request'

module Motivoo
  
  # A unique visitor tracked using a cookie and based on an external user id (for users that signed up in the application using Motivoo).
  #
  class UserData
    USER_ID_COOKIE = "_muid"
    EXT_USER_ID_KEY = "ext_user_id"
    COHORTS_KEY = "cohorts"
   
    # Creates a UserData instance based on a Rack env.
    #
    def self.deserialize_from(env, connection)
      user_id, user_data, is_existing_user = 
        if (existing_user_id = Rack::Request.new(env).cookies[USER_ID_COOKIE])
          [existing_user_id, connection.find_or_create_user_data(existing_user_id), true]
        else
          [connection.generate_user_id, {}, false]
        end
      [UserData.new(user_id, user_data, connection), is_existing_user]
    end
    
    # Updates Rack::Response to facilitate user tracking.
    #
    def serialize_into(response)
      response.set_cookie(USER_ID_COOKIE, value: @user_id, path: "/", expires: Time.now + 3 * 30 * 24 * 60 * 60)
    end

    # Creates a UserData instance.
    #
    def initialize(user_id, hash, connection)
      @user_id = user_id
      @ext_user_id = hash[EXT_USER_ID_KEY]
      @cohorts = hash[COHORTS_KEY] || {}
      @connection = connection
    end
    
    def initialize_copy(_)
      self
      @cohorts = @cohorts.clone
    end
    
    # Assigns the current user to a cohort.
    #
    def assign_to(cohort_name, cohort)
      raise "User already assigned (#{cohort_name.inspect})" if @cohorts[cohort_name]
      @connection.assign_cohort(@user_id, cohort_name, cohort)
      @cohorts.store(cohort_name, cohort)
    end
    
    # Returns cohorts the current user is assigned to or an empty hash.
    #
    def cohorts
      @cohorts
    end
    
    # Associates the current user with an external user id, usually pointing to an id in the user's database of the application using Motivoo.
    #
    def set_ext_user_id(ext_user_id)
      # puts "set_ext_user_id(#{ext_user_id.inspect}) <-- @ext_user_id = #{@ext_user_id.inspect} -- @user_id = #{@user_id.inspect} -- @cohorts = #{@cohorts.inspect}"
      return if @ext_user_id == ext_user_id

      if ext_user_id.nil?
        @cohorts = {}
        @user_id = @connection.generate_user_id
      else
        user_id, user_data = @connection.find_user_data_by_ext_user_id(ext_user_id)
      
        if user_id
          @connection.destroy_user_data(@user_id) if @ext_user_id.nil?
          @cohorts = user_data[COHORTS_KEY]
          @user_id = user_id
        elsif @ext_user_id.nil?
          @connection.set_user_data(@user_id, EXT_USER_ID_KEY => ext_user_id)
        else
          @cohorts = {}
          @user_id = @connection.generate_user_id
          @connection.set_user_data(@user_id, EXT_USER_ID_KEY => ext_user_id)
        end
      end
      @ext_user_id = ext_user_id
      # puts "--> @ext_user_id = #{@ext_user_id.inspect} -- @user_id = #{@user_id.inspect} -- @cohorts = #{@cohorts.inspect}"
    end
    
    # External user id the current user is associated with.
    #
    def ext_user_id
      @ext_user_id
    end
    
    # Internal id of the currently tracked user.
    # Note: It's not the same as external user id set by a call to set_ext_user_id!
    #
    def user_id
      @user_id
    end
    
    # Time of the user's first visit.
    def first_visit_at
      @connection.user_data_created_at(@user_id)
    end
    
    # Returns a user-defined user data field.
    #
    def [](key)
      # TODO: Cache it?
      value = @connection.get_user_data(@user_id, key)
      # puts "#{@user_id} [](#{key.inspect}) => #{value.inspect}"
      value
    end
    
    # Sets a user-defined user data field.
    #
    def []=(key, value)
      # puts "#{@user_id} []=(#{key.inspect}, #{value.inspect})"
      # TODO ext_user_id can be set directly by the user bypassing code in UserData#set_ext_user_id
      @connection.set_user_data(@user_id, key => value)
    end
    
    # Testing
    
    def inspect
      "{UserData @cohorts=#{@cohorts.inspect} @ext_user_id=#{@ext_user_id.inspect} @user_id=#{@user_id.inspect}}"
    end
  end
end