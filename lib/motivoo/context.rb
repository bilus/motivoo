require_relative 'connection'
require_relative 'tracker'
require_relative 'user_data'
require 'rack/request'

module Motivoo

  # Context for the execution of tracking based on an env hash.
  #
  class Context
    
    # Creates the context for a given block. Used by Rack::Motivoo middleware.
    #
    def self.create(env)
      connection = Connection.instance
      user_data, is_existing_user = UserData.deserialize_from(env, connection)
      tracker = Tracker.new(user_data, connection, existing_user: is_existing_user)
      request = Rack::Request.new(tracker.serialize_into(env))
      
      if block_given?
        response = yield(tracker, request) 
        user_data.serialize_into(response)
        response.finish
      end
    end
  end
end