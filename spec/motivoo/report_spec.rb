require 'spec_helper'
require 'motivoo/report'

describe Motivoo::Report do
  let(:connection) { mock("connection").as_null_object }
  let(:report) { Motivoo::Report.new(connection) }
  
  shared_examples_for "report with absolute values" do
    it "should delegate to connection" do
      connection.should_receive(:find).with(expected_category, expected_status, expected_cohort_name)
      report_method.call
    end
  end

  describe "when queried for acquisition report" do
    it_should_behave_like "report with absolute values" do
      let(:report_method) { lambda { report.acquisitions_by(expected_cohort_name.to_sym, expected_status.to_sym) } }
      let(:expected_category) { "acquisition" }
      let(:expected_status) { "visit" }
      let(:expected_cohort_name) { "month" }
    end
  end

  describe "when queried for activation report" do
    it_should_behave_like "report with absolute values" do
      let(:report_method) { lambda { report.activations_by(expected_cohort_name.to_sym, expected_status.to_sym) } }
      let(:expected_category) { "activation" }
      let(:expected_status) { "visit" }
      let(:expected_cohort_name) { "month" }
    end
  end

  describe "when queried for retention report" do
    it_should_behave_like "report with absolute values" do
      let(:report_method) { lambda { report.retentions_by(expected_cohort_name.to_sym, expected_status.to_sym) } }
      let(:expected_category) { "retention" }
      let(:expected_status) { "visit" }
      let(:expected_cohort_name) { "month" }
    end
  end

  describe "when queried for referral report" do
    it_should_behave_like "report with absolute values" do
      let(:report_method) { lambda { report.referrals_by(expected_cohort_name.to_sym, expected_status.to_sym) } }
      let(:expected_category) { "referral" }
      let(:expected_status) { "visit" }
      let(:expected_cohort_name) { "month" }
    end
  end

  describe "when queried for revenue report" do
    it_should_behave_like "report with absolute values" do
      let(:report_method) { lambda { report.revenues_by(expected_cohort_name.to_sym, expected_status.to_sym) } }
      let(:expected_category) { "revenue" }
      let(:expected_status) { "visit" }
      let(:expected_cohort_name) { "month" }
    end
  end
  
  shared_examples_for "report with values relative to visits" do
    let(:current_status) { "second_visit" }
    
    it "should fetch visit stats" do
      connection.should_receive(:find).with("acquisition", "visit", expected_cohort_name).and_return({})
      report.relative_acquisitions_by(expected_cohort_name, current_status)
    end
    
    it "should fetch stats for the current_status and calc the ratio" do
      connection.stub!(:find).with("acquisition", "visit", expected_cohort_name).and_return({ "2012-10" => 4, "2012-11" => 10})
      connection.should_receive(:find).with(expected_category, current_status, expected_cohort_name).and_return({"2012-10" => 1, "2012-11" => 5})

      report.relative_acquisitions_by(expected_cohort_name, current_status).should == {"2012-10" => 0.25, "2012-11" => 0.5}
    end

    it "should assume 100% ratio when no visits" do
      connection.stub!(:find).with("acquisition", "visit", expected_cohort_name).and_return({ "2012-10" => 0, "2012-11" => nil})
      connection.should_receive(:find).with(expected_category, current_status, expected_cohort_name).and_return({"2012-10" => 1, "2012-11" => 5})

      report.relative_acquisitions_by(expected_cohort_name, current_status).should == {"2012-10" => 1.0, "2012-11" => 1.0}
    end
  end
end