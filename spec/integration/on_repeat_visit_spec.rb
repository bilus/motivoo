require 'spec_helper'

describe "Repeat visit callback" do

  let(:callback) { mock_event_handler }

  include SpecHelpers
  
  def app
    app = Rack::Builder.app do
      use Rack::Motivoo
      run lambda { |env|
        path = env["PATH_INFO"]
        case path
        when %r{^/login/(.*)}
          username = $1
          Motivoo::Tracker.deserialize_from(env).set_ext_user_id(username)
        when %r{^/signup/(.*)}
          username = $1
          Motivoo::Tracker.deserialize_from(env).set_ext_user_id(username)
        end
        [200, {'Content-Type' => 'text/plain'}, ["Hello"]]
      }
    end
  end
  
  
  before(:each) do
    Motivoo.configure do |config|
      config.on_repeat_visit(&callback)
    end
  end

  after(:all) do
    Motivoo.configure do |config|
      config.on_repeat_visit {}
    end
  end
  
  it "should not trigger on fresh visit" do
    callback.should_not_receive(:call)
    get("/")
  end
  
  it "should trigger for user coming back" do
    callback.should_receive(:call).once
    user = get("/")
    get("/", user)
  end
  
  it "should trigger for user coming back and logging in" do
    callback.should_receive(:call).once
    user = get("/")
    get("/login/bilus", user)
  end
  
  it "should trigger for user comming back as anonymous and then logging in" do
    callback.should_receive(:call).once
    get("/signup/bilus")
    get("/login/bilus")
  end
end