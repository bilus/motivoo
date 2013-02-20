$: << "../../lib"

require 'time'
require 'timecop'
require 'motivoo/connection'

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