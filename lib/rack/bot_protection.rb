require 'erb'

require 'motivoo/tracker'
require 'motivoo/limited_tracker'

module Rack
  class BotProtection
    def self.maybe_protect(app)
      if ::Motivoo.configuration.bot_protect_js
        @app = BotProtected.new(app)
      else
        @app = Unprotected.new(app)
      end
    end
    
    private
    
    class Unprotected
      def initialize(app)
        @app = app
      end
      
      def call(env)
        @app.call(env)
      end

      def with_context_for(env, &block)
        ::Motivoo::Context.create(env, proc { ::Motivoo::Tracker }, &block)
      end
    end
    
    class BotProtected
      def initialize(app)
        @app = app
      end
      
      def call(env)
        config = ::Motivoo.configuration
        case env["PATH_INFO"]
        when config.bot_protect_js_path
          generate_response(200, "text/javascript", read_bot_protect_js)
        when config.bot_protect_path
          if env["REQUEST_METHOD"] == "POST"
            generate_response(200, "application/json", '{"status":"ok"}')
          else
            generate_response(404, "text/html", "<h1>Not found</h1>")
          end
        else
          status, headers, body = @app.call(env)
          maybe_inject_bot_protect_script(status, headers, body)
        end
      end

      def with_context_for(env, &block)
        tracker_factory = proc do |user_data|
          if start_track?(env)
            user_data["track"] = true
            ::Motivoo::Tracker
          elsif user_data["track"]
            ::Motivoo::Tracker
          else
            ::Motivoo::LimitedTracker
          end
        end

        # Actual tracking using NullTracker or real Tracker.
        ::Motivoo::Context.create(env, tracker_factory, &block)
      end
    
      private

      def start_track?(env)
        config = ::Motivoo.configuration
        env["PATH_INFO"] == config.bot_protect_path
      end

      def render_asset(path)
        template = ::File.read(::File.expand_path(::File.join("../../assets/", path), __FILE__))
        ERB.new(template).result
      end
      
      def read_bot_protect_js
        render_asset("javascripts/motivoo.js.erb")
      end
      
      def read_bot_protect_script
        render_asset("script.html.erb")
      end
        
      def maybe_inject_bot_protect_script(status, headers, body)
        ct = headers["Content-Type"] || ""
        if ct.include?("text/html") && status.to_i == 200
          se = read_bot_protect_script
          body.each {|b| b.gsub!(/(<\/head>|<\/body>|<\/html\/>)/i, "#{se}" + '\1')}
          headers["Content-Length"] = (headers["Content-Length"].to_i + se.length).to_s
        end
        [status, headers, body]
      end
    
      def generate_response(status, content_type, body)
        [
          status, 
          {"Content-Type" => content_type, "Content-Length" => body.length.to_s},
          [body]
        ]
      end      
    end
  end
end