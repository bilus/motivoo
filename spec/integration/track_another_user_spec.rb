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
          tracker = Motivoo::Tracker.deserialize_from(env)
          tracker.activation(:called)
          username = $1
          tracker.act_as(username).activation(:received_call)
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
    report.activations_by(:month, :received_call).should == {"2012-12" => 2}
    report.activations_by(:month, :called).should == {"2012-12" => 1}
  end
end