$: << "../../lib"

require 'time'
require 'timecop'
require 'motivoo/connection'
require 'motivoo/report'
require 'motivoo/tracker'
require 'rack/motivoo'

require 'rack/test'

def at(time_str) 
  Timecop.freeze(Time.parse(time_str)) do
    yield
  end
end
  
connection = Motivoo::Connection.new  # So it doesn't leak connections.
  
RSpec.configure do |config|
  config.before(:each) do
    connection.clear!
  end
end

module SpecHelpers
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
  
  def report
    Motivoo::Report.new(Motivoo::Connection.new)
  end
end