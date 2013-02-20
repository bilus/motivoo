require 'spec_helper'
require 'motivoo/connection'
require 'motivoo/report'
require 'rack/motivoo'
require 'rack/test'

describe "Acquisition" do
  include RequestHelpers
  
  let(:connection) { Motivoo::Connection.new }
  let(:report) { Motivoo::Report.new(connection) }
  
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
    res = nil
    at("2012-12-12 15:00") {res = get("/") }
    at("2012-12-12 15:00") { get("/", "HTTP_COOKIE" => res["Set-Cookie"]) }
    report.acquisitions_by(:month, :visit).should == {"2012-12" => 1}
  end
end