require 'spec_helper'
require 'motivoo/report'

describe Motivoo::Report do
  let(:connection) { mock("connection").as_null_object }
  let(:report) { Motivoo::Report.new(connection) }
  
  shared_examples_for "report with absolute values" do
    it "should delegate to connection" do
      connection.should_receive(:find).with(expected_category, expected_status, expected_cohort_name)
      absolute_report_method.call
    end
  end

  shared_examples_for "report with values relative to a report with absolute values" do
    let(:current_status) { "second_visit" }
    
    it "should fetch stats for the current_status and calc the ratio" do
      connection.should_receive(:find).with(expected_category, current_status, expected_cohort_name).and_return({"2012-10" => 1, "2012-11" => 5})
      relative_report_method.call(expected_cohort_name, current_status, { "2012-10" => 4, "2012-11" => 10}).should == {"2012-10" => 0.25, "2012-11" => 0.5}
    end

    it "should assume 100% ratio when no visits" do
      connection.should_receive(:find).with(expected_category, current_status, expected_cohort_name).and_return({"2012-10" => 1, "2012-11" => 5})
      relative_report_method.call(expected_cohort_name, current_status, { "2012-10" => 0, "2012-11" => nil}).should == {"2012-10" => 1.0, "2012-11" => 1.0}
    end
  end

  describe "when queried for acquisition report" do
    let(:expected_category) { "acquisition" }
    let(:expected_status) { "visit" }
    let(:expected_cohort_name) { "month" }

    it_should_behave_like "report with absolute values" do
      let(:absolute_report_method) { lambda { report.acquisitions_by(expected_cohort_name.to_sym, expected_status.to_sym) } }
    end
    
    it_should_behave_like "report with values relative to a report with absolute values" do
      let(:relative_report_method) { lambda { |category, status, base_report| report.relative_acquisitions_by(category, status, base_report) } }
    end
  end

  describe "when queried for activation report" do
    let(:expected_category) { "activation" }
    let(:expected_status) { "visit" }
    let(:expected_cohort_name) { "month" }

    it_should_behave_like "report with absolute values" do
      let(:absolute_report_method) { lambda { report.activations_by(expected_cohort_name.to_sym, expected_status.to_sym) } }
    end

    it_should_behave_like "report with values relative to a report with absolute values" do
      let(:relative_report_method) { lambda { |category, status, base_report| report.relative_activations_by(category, status, base_report) } }
    end
  end

  describe "when queried for retention report" do
    let(:expected_category) { "retention" }
    let(:expected_status) { "visit" }
    let(:expected_cohort_name) { "month" }

    it_should_behave_like "report with absolute values" do
      let(:absolute_report_method) { lambda { report.retentions_by(expected_cohort_name.to_sym, expected_status.to_sym) } }
    end

    it_should_behave_like "report with values relative to a report with absolute values" do
      let(:relative_report_method) { lambda { |category, status, base_report| report.relative_retentions_by(category, status, base_report) } }
    end
  end

  describe "when queried for referral report" do
    let(:expected_category) { "referral" }
    let(:expected_status) { "visit" }
    let(:expected_cohort_name) { "month" }

    it_should_behave_like "report with absolute values" do
      let(:absolute_report_method) { lambda { report.referrals_by(expected_cohort_name.to_sym, expected_status.to_sym) } }
    end

    it_should_behave_like "report with values relative to a report with absolute values" do
      let(:relative_report_method) { lambda { |category, status, base_report| report.relative_referrals_by(category, status, base_report) } }
    end
  end

  describe "when queried for revenue report" do
    let(:expected_category) { "revenue" }
    let(:expected_status) { "visit" }
    let(:expected_cohort_name) { "month" }

    it_should_behave_like "report with absolute values" do
      let(:absolute_report_method) { lambda { report.revenues_by(expected_cohort_name.to_sym, expected_status.to_sym) } }
    end

    it_should_behave_like "report with values relative to a report with absolute values" do
      let(:relative_report_method) { lambda { |category, status, base_report| report.relative_revenues_by(category, status, base_report) } }
    end
  end
  
end