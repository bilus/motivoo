$: << "../../lib"

require 'time'
require 'timecop'
require 'motivoo/connection'
require 'motivoo/report'
require 'motivoo/tracker'
require 'rack/motivoo'

require 'rack/test'

require 'awesome_print'

def at(time_str) 
  result = nil
  Timecop.freeze(Time.parse(time_str)) do
    # print "\nat #{time_str} "
    result = yield
  end
  result
end

def mock_event_handler
  handler = double("handler")
  l = Proc.new do |*args| 
    begin
      handler.call(*args)
    end
  end
  handler.stub(:to_proc).and_return(l)
  handler
end
  
RSpec.configure do |config|
  config.before(:each) do
    Motivoo::Connection.instance.clear!
    Motivoo.configuration.reset!
  end
end

module SpecHelpers
  def response_from(opts)
    if opts.is_a?(Rack::Response)
      res = opts
      {"HTTP_COOKIE" => (res["Set-Cookie"] || "").split("\n").join(";")}
    else
      opts || {}
    end
  end
  
  def get(path, opts = {})
    Rack::MockRequest.new(app).get(path, response_from(opts))
  end
  
  def post(path, opts = {})
    Rack::MockRequest.new(app).post(path, response_from(opts))
  end
  
  def report
    Motivoo::Report.new(Motivoo::Connection.instance)
  end
end