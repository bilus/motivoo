require 'spec_helper'
require 'motivoo/report'

describe Motivoo::Report do
  let(:connection) { mock("connection").as_null_object }
  let(:report) { Motivoo::Report.new(connection) }
  
  describe "when queried about acquisitions" do
    it "should delegate to connection" do
      connection.should_receive(:find).with("acquisition", "visit", "month")
      report.acquisitions_by(:month, :visit)
    end
  end

  describe "when queried for activations" do
    it "should delegate to connection" do
      connection.should_receive(:find).with("activation", "signup", "month")
      report.activations_by(:month, :signup)
    end
  end
end