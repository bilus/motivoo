require 'spec_helper'

describe "Activation" do
  include SpecHelpers
  
  def app
    Rack::Builder.app do
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

  it "should track each acquisition only once for the same user" do
    user1 = nil
    
    at("2012-10-10 12:00") { user1 = get("/") }
    at("2012-10-10 14:00") { get("/signup", user1) }
    at("2012-10-10 14:00") { get("/", user1) }
    at("2012-12-15 14:00") { get("/login") }
  end

  it "should report relative values by cohort" do
    report.relative_activations_by(:month, :signup, report.acquisitions_by(:month, :first_visit)).should == {"2012-10" => 0.5, "2012-11" => 1.0, "2012-12" => 0.25}
  end
end