require_relative '../motivoo/context'

module Rack
  class Motivoo
    def initialize(app)
      @app = app
    end
    
    TRACKED_COOKIE_KEY = "motivoo.tracked"
    
    def call(env)
      ::Motivoo::Context.create(env) do |tracker, request|
        unless request.cookies[TRACKED_COOKIE_KEY]
          tracker.acquisition(:visit)
        end

        status, headers, body = @app.call(request.env)

        response = Response.new(body, status, headers)
        response.set_cookie(TRACKED_COOKIE_KEY, true)
        response  # tracker created user data and calls serialize_into(response) and response.finish
      end
   end
  end
end