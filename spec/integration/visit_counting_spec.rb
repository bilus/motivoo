require 'spec_helper'
require 'motivoo/connection'
require 'motivoo/tracker'
require 'motivoo/report'

describe "Visit counting" do
  let(:db) { Motivoo::Connection.new }
  let(:tracker) { Motivoo::Tracker.new(db) }
  let(:report) { Motivoo::Report.new(db) }
  
  def at(time_str) 
    Timecop.freeze(Time.parse(time_str)) do
      yield
    end
  end
  
  it "should track visits by time" do
    at("2012-11-10 12:00") { tracker.acquisition(:visit) }
    at("2012-11-10 12:00") { tracker.acquisition(:visit) }
    at("2012-11-10 12:00") { tracker.acquisition(:visit) }
    at("2012-11-10 12:00") { tracker.acquisition(:visit) }
    at("2012-12-11 11:00") { tracker.acquisition(:visit) }
    at("2012-12-12 13:00") { tracker.acquisition(:visit) }
    at("2012-12-12 13:00") { tracker.acquisition(:visit) }
    at("2012-12-12 14:00") { tracker.acquisition(:visit) }
    at("2012-12-12 15:00") { tracker.acquisition(:visit) }
    report.acquisitions_by(:month, :visit).should == [{"2012-11" => 4}, {"2012-12" => 5}]
  end
  
  it "should not include clicks during the same session in visit count" do
    at("2012-11-10 12:00") { tracker.acquisition(:visit) }
    at("2012-11-10 13:00") { tracker.acquisition(:visit, click: true) }
    report.acquisitions_by(:month, :visit).should == [{"2012-11" => 1}]
  end
end