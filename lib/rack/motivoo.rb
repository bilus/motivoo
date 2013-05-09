require_relative '../motivoo/context'
require_relative '../motivoo/visit'

module Rack
  
  # Rack middleware.
  # 
  # Usage:
  #   use Rack::Motivoo
  #
  class Motivoo
    def initialize(app)
      @app = app
    end
    
    def call(env)
      return @app.call if env["PATH_INFO"] =~ %r{^/favicon.ico$} # TODO: Make it configurable somehow(?). FIX: No cookies passed when requesting favicon.ico which results in new user data record created for every request.
        
      ::Motivoo::Context.create(env) do |tracker, request|
        ::Motivoo::Visit.track(tracker, request) do |tracker, request|
          status, headers, body = @app.call(request.env)

          response = Response.new(body, status, headers)
          response  # tracker created user data and calls serialize_into(response) and response.finish
        end
      end
   end
  end
end