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
      ::Motivoo::Context.create(env) do |tracker, request|
        if track_path?(request)
          ::Motivoo::Visit.track(tracker, request) do |tracker, request|
            call_wrapped_app(request) 
          end
        else
          call_wrapped_app(request)
        end
      end
    end
    
    protected
    
    def track_path?(request)
      # FIX: No cookies passed by Chrome when it requests favicon.ico/png which results in new user data record being 
      # created for every request. AFAIK, IE keeps a separate cookie store for favicon requests. 
      # Actually, we don't care about binary files at all, so while we're at it, let's ignore them all. In production environment, 
      # most of these assets will be fetched from an asset server but it won't hurt to ignore them anyway while at the same time 
      # taking care of favicons -- THE serious offenders.
      is_binary = request.env["PATH_INFO"] =~ /\.jpg|jpeg|png|ico|gif|pdf|tif|tiff|doc|xls|docx|xlsx|css|js$/i
      !is_binary
    end
    
    def call_wrapped_app(request)
      event, headers, body = @app.call(request.env)
      Response.new(body, event, headers)
    end
  end
end