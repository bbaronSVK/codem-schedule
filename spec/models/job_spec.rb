require 'spec_helper'

describe Job do
  describe "generating a job via the API" do
    before(:each) do
      @preset = FactoryGirl.create(:preset)
    end

    describe "successfull save" do
      before(:each) do
        @job = Job.from_api(
          { 
            "input" => "input", 
            "output" => "output", 
            "priority" => 1,
            "preset" => @preset.name, 
            "arguments" => "a=b,c=d"
          }, 
          :callback_url => lambda { |job| "callback_#{job.id}" }
        )
      end
      
      it "should map the attributes correctly" do
        @job.source_file.should == 'input'
        @job.destination_file.should == 'output'
        @job.preset.should == @preset
        @job.callback_url.should == "callback_#{@job.id}"
        @job.priority.should == 1
        @job.arguments.should == { :a => 'b', :c => 'd' }
      end
      
      it "should be saved" do
        @job.should_not be_new_record
      end
    
      it "should be in the scheduled state" do
        @job.state.should == Job::Scheduled
      end
    end
    
    describe "failed save" do
      before(:each) do
        @job = Job.from_api({}, {})
      end
      
      it "should not be saved" do
        @job.should be_new_record
      end
    end
  end

  describe "finished" do
    it "should be finished if Success" do
      Job.new(:state => Job::Success).should be_finished
    end

    it "should be finished if Failed" do
      Job.new(:state => Job::Failed).should be_finished
    end
  end
  
  describe "unfinished" do
    it "should be unfinished if Scheduled" do
      Job.new(:state => Job::Scheduled).should be_unfinished
    end

    it "should be unfinished if Processing" do
      Job.new(:state => Job::Processing).should be_unfinished
    end

    it "should be unfinished if Processing" do
      Job.new(:state => Job::OnHold).should be_unfinished
    end
  end
  
  describe "needs update" do
    it "should need an update if Processing" do
      Job.new(:state => Job::Processing).should be_needs_update
    end
    
    it "should need an update if OnHold" do
      Job.new(:state => Job::OnHold).should be_needs_update
    end
  end
  
  describe "getting the recent jobs" do
    before do
      @scope = double("Scope")
      @scope.stub(:recent).and_return @scope
      @scope.stub(:order).and_return @scope
      @scope.stub(:page).and_return @scope

      Job.stub(:scoped).and_return @scope
      Job.stub(:search).and_return @scope
    end

    it "should accept a query" do
      Job.should_receive(:search).with('q')
      Job.recents(query: 'q')
    end

    it "should accept an order and direction" do
      @scope.should_receive(:order).with('jobs.foo bar')
      Job.recents(sort: 'foo', dir: 'bar')
    end
  end

  describe "searching" do
    before(:each) do
      @scope = Job.scoped
      @scope.stub(:where).and_return @scope
      Job.stub(:scoped).and_return @scope
    end

    def search(str)
      Job.search(str)
    end

    it "should find a job by id" do
      @scope.should_receive(:where).with('jobs.id = ?', '1')
      search('id:1')
    end

    it "should find a job by state" do
      @scope.should_receive(:where).with('state = ?', 'failed')
      search('state:failed')
    end

    it "should find a job by source" do
      @scope.should_receive(:where).with('source_file LIKE ?', '%foo%')
      search('source:foo')
    end

    it "should find a job by input" do
      @scope.should_receive(:where).with('source_file LIKE ?', '%foo%')
      search('input:foo')
    end

    it "should find a job by dest" do
      @scope.should_receive(:where).with('destination_file LIKE ?', '%foo%')
      search('dest:foo')
    end

    it "should find a job by output" do
      @scope.should_receive(:where).with('destination_file LIKE ?', '%foo%')
      search('output:foo')
    end

    it "should find a job by file" do
      @scope.should_receive(:where).with('source_file LIKE ? OR destination_file LIKE ?', '%foo%', '%foo%')
      search('file:foo')
    end

    it "should find a job by preset" do
      @scope.should_receive(:where).with('presets.name LIKE ?', '%foo%')
      search('preset:foo')
    end

    it "should find a job by host" do
      @scope.should_receive(:where).with('hosts.name LIKE ?', '%foo%')
      search('host:foo')
    end

    it "should find a job by submitted" do
      t0 = 2.days.ago.at_beginning_of_day
      t1 = t0 + 1.day
      @scope.should_receive(:where).with('jobs.created_at BETWEEN ? AND ?', t0, t1)
      search('submitted:2_days_ago')
    end

    it "should find a job by completed" do
      t0 = 2.days.ago.at_beginning_of_day
      t1 = t0 + 1.day
      @scope.should_receive(:where).with('jobs.completed_at BETWEEN ? AND ?', t0, t1)
      search('completed:2_days_ago')
    end

    it "should find a job by started" do
      t0 = 2.days.ago.at_beginning_of_day
      t1 = t0 + 1.day
      @scope.should_receive(:where).with('jobs.transcoding_started_at BETWEEN ? AND ?', t0, t1)
      search('started:2_days_ago')
    end

    it "should work with an invalid date" do
      @scope.should_not_receive(:where)
      search('started:foo_bar_baz')
    end

    it "all together now!" do
      t0 = 2.days.ago.at_beginning_of_day
      t1 = t0 + 1.day

      @scope.should_receive(:where).with('jobs.id = ?', '1')
      @scope.should_receive(:where).with('state = ?', 'failed')
      @scope.should_receive(:where).with('source_file LIKE ?', '%foo%')
      @scope.should_receive(:where).with('destination_file LIKE ?', '%foo%')
      @scope.should_receive(:where).with('source_file LIKE ? OR destination_file LIKE ?', '%foo%', '%foo%')
      @scope.should_receive(:where).with('presets.name LIKE ?', '%foo%')
      @scope.should_receive(:where).with('hosts.name LIKE ?', '%foo%')
      @scope.should_receive(:where).with('jobs.created_at BETWEEN ? AND ?', t0, t1)
      @scope.should_receive(:where).with('jobs.completed_at BETWEEN ? AND ?', t0, t1)
      @scope.should_receive(:where).with('jobs.transcoding_started_at BETWEEN ? AND ?', t0, t1)

      search('id:1 state:failed source:foo dest:foo file:foo preset:foo host:foo created:2_days_ago completed:2_days_ago started:2_days_ago')
    end
  end

  describe "show" do
    it "should use the correct includes" do
      Job.should_receive(:find).with(1, :include => [:host, :preset, [:state_changes => [:deliveries => :notification]]])
      Job.show(1)
    end
  end

  describe 'deleting a job' do
    subject { FactoryGirl.create(:job) }

    it 'should delete the job from the transcoder' do
      Transcoder.should_receive(:remove_job).with(subject)
      subject.destroy
    end

    it 'should always return true' do
      subject.send(:remove_job_from_transcoder).should == true
    end
  end
end
