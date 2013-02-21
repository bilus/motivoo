require 'spec_helper'

describe "Acquisition" do
  include SpecHelpers
  
  def app
    app = Rack::Builder.app do
      use Rack::Motivoo
      run lambda { |env|
        [200, {'Content-Type' => 'text/plain'}, ["Hello"]]
      }
    end
  end
  
  it "should track visits by time" do
    at("2012-11-10 12:00") { get("/") }
    at("2012-11-10 12:00") { get("/") }
    at("2012-11-10 12:00") { get("/") }
    at("2012-11-10 12:00") { get("/") }
    at("2012-12-11 11:00") { get("/") }
    at("2012-12-12 13:00") { get("/") }
    at("2012-12-12 13:00") { get("/") }
    at("2012-12-12 14:00") { get("/") }
    at("2012-12-12 15:00") { get("/") }
    report.acquisitions_by(:month, :visit).should == {"2012-11" => 4, "2012-12" => 5}
  end
  
  it "should not include clicks during the same session in visit count" do
    user = nil
    at("2012-12-12 15:00") {user = get("/") }
    at("2012-12-12 15:00") { get("/", user) }
    report.acquisitions_by(:month, :visit).should == {"2012-12" => 1}
  end
end