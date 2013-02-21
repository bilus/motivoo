$: << "../../lib"

require 'time'
require 'timecop'
require 'motivoo/connection'
require 'rack/test'

def at(time_str) 
  Timecop.freeze(Time.parse(time_str)) do
    yield
  end
end
  
RSpec.configure do |config|
  config.before(:each) do
    Motivoo::Connection.new.clear!
  end
end

module RequestHelpers
  def get(path, opts = {})
    options = 
      if opts.is_a?(Rack::Response)
        res = opts
        {"HTTP_COOKIE" => res["Set-Cookie"].split("\n").join(";")}
      else
        opts
      end
    Rack::MockRequest.new(app).get(path, options)
  end
end