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
      # FIX: No cookies passed by Chrome when it requests favicon.ico/png which results in new user data record being created for every request. AFAIK, IE keeps a separate cookie store for favicon requests. 
      # Actually, we don't care about binary files at all, so while we're at it, let's ignore them all. In production environment, most of these assets will be fetched from an asset server but it won't hurt to ignore them anyway while at the same time taking care of favicons -- THE serious offenders.
      return @app.call(env) if env["PATH_INFO"] =~ /\.jpg|jpeg|png|ico|gif|pdf|tif|tiff|doc|xls|docx|xlsx|css|js$/i
        
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