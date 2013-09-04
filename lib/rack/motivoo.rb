require_relative '../motivoo/context'
require_relative '../motivoo/visit'
require 'erb'

module Rack
  
  # Rack middleware.
  # 
  # Usage:
  #   use Rack::Motivoo
  #
  class Motivoo
    def initialize(app)
      @app = app
      if ::Motivoo.configuration.bot_protect_js
        @app = bot_protected(app)
      end
    end
    
    def call(env)
      with_context_for(env) do |tracker, request|
        if track_path?(request)
          ::Motivoo::Visit.track(tracker, request) do |tracker, request|
            app_response_to(request) 
          end
        else
          app_response_to(request)
        end
      end
    end
    
    protected
    
    def with_context_for(env, &block)
      m = force_create_context?(env) ? :create! : :create
      ::Motivoo::Context.send(m, env, &block)
    end
    
    def force_create_context?(env)
      config = ::Motivoo.configuration
      !config.bot_protect_js || env["PATH_INFO"] == config.bot_protect_path
    end
    
    def track_path?(request)
      # FIX: No cookies passed by Chrome when it requests favicon.ico/png which results in new user data record being 
      # created for every request. AFAIK, IE keeps a separate cookie store for favicon requests. 
      # Actually, we don't care about binary files at all, so while we're at it, let's ignore them all. In production environment, 
      # most of these assets will be fetched from an asset server but it won't hurt to ignore them anyway while at the same time 
      # taking care of favicons -- THE serious offenders.
      is_binary = request.env["PATH_INFO"] =~ /\.jpg|jpeg|png|ico|gif|pdf|tif|tiff|doc|xls|docx|xlsx|css|js$/i
      !is_binary
    end
    
    def app_response_to(request)
      status, headers, body = @app.call(request.env)
      Response.new(body, status, headers)
    end
    
    ####
    
    def read_bot_protect_js
      template = ::File.read(::File.expand_path("../../assets/javascripts/motivoo.js.erb", __FILE__))
      ERB.new(template).result
    end
    
    def bot_protected(app)
      config = ::Motivoo.configuration
      lambda do |env|
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
          status, headers, body = app.call(env)
          inject_bot_protect_js(status, headers, body)
        end
      end
    end
    
    def bot_protect_script_element
      "
<script>(function(d, s, id) {
  var js, fjs = d.getElementsByTagName(s)[0];
  if (d.getElementById(id)) return;
  js = d.createElement(s); js.id = id;
  js.src = '#{::Motivoo.configuration.bot_protect_js_path}';
  fjs.parentNode.insertBefore(js, fjs);
}(document, 'script', 'motivoo'));</script>"
    end
        
    def inject_bot_protect_js(status, headers, body)
      se = bot_protect_script_element
      body.each {|b| b.gsub!(/(<\/head>|<\/body>|<\/html\/>)/i, "#{se}" + '\1')}
      headers["Content-Length"] = (headers["Content-Length"].to_i + se.length).to_s
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