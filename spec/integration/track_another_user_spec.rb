require 'spec_helper'

describe "Track another user" do

  include SpecHelpers
  
  def app
    app = Rack::Builder.app do
      use Rack::Motivoo
      run lambda { |env|
        path = env["PATH_INFO"]
        case path
        when %r{^/contact/(.*)}
          username = $1
          Motivoo::Tracker.deserialize_from(env).act_as!(username).activation(:contact)
        when %r{^/login/(.*)}
          username = $1
          Motivoo::Tracker.deserialize_from(env).set_ext_user_id(username)
        end
        [200, {'Content-Type' => 'text/plain'}, ["Hello"]]
      }
    end
  end
  
  it "should track another user" do
    user = nil
    at("2012-12-12 16:00") { user = get("/contact/jerry") }
    at("2012-12-12 16:00") { get("/contact/tom", user) }
    at("2012-12-12 16:00") { get("/contact/tom", user) }
    report.activations_by(:month, :contact).should == {"2012-12" => 2}
  end
end