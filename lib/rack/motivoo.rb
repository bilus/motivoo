require_relative '../motivoo/context'
require_relative '../motivoo/visit'

module Rack
  class Motivoo
    def initialize(app)
      @app = app
    end
    
    def call(env)
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