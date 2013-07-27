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
      # FIX: No cookies passed by Chrome when it requests favicon.ico/png which results in new user data record being created for every request. AFAIK, IE keeps a separate cookie store for favicon requests. So let's ignore these requests completely.
      return @app.call if env["PATH_INFO"] =~ %r{^/favicon\.[a-z]+$}
        
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