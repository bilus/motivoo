require 'spec_helper'
require 'motivoo/connection'
require 'motivoo/report'
require 'motivoo/tracker'
require 'rack/motivoo'
require 'rack/test'

describe "Activation" do
  let(:connection) { Motivoo::Connection.new }
  let(:report) { Motivoo::Report.new(connection) }
  
  def app
    app = Rack::Builder.app do
      use Rack::Motivoo
      map "/" do
        run lambda { |env|
          [200, {'Content-Type' => 'text/plain'}, ["Hello"]]
        }
      end
      
      map "/signup" do
        run lambda { |env|
          Motivoo::Tracker.deserialize_from(env).activation(:signup)
          [200, {'Content-Type' => 'text/plain'}, ["Hello"]]
        }
      end
    end
  end
  
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

  before(:each) do
    user1, user2, user3 = nil, nil, nil
    
    at("2012-10-10 12:00") { user1 = get("/") }
    at("2012-10-10 13:00") { get("/") }
    at("2012-10-10 14:00") { get("/signup", user1) }
    
    at("2012-11-01 11:00") { user2 = get("/") }
    at("2012-11-02 12:00") { get("/signup", user2) }  # Treats it like a visit?
    
    at("2012-12-12 12:00") { get("/") }
    at("2012-12-12 13:00") { user3 = get("/") }
    at("2012-12-12 14:00") { get("/") }
    at("2012-12-12 15:00") { get("/") }
    at("2012-12-12 16:00") { get("/signup", user3) }
  end

  it "should report absolute values by cohort" do
    report.activations_by(:month, :signup).should == {"2012-10" => 1, "2012-11" => 1, "2012-12" => 1}
  end

  it "should report relative values by cohort" do
    report.relative_activations_by(:month, :signup).should == {"2012-10" => 0.5, "2012-11" => 1.0, "2012-12" => 0.25}
  end
end