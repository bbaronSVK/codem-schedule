require 'spec_helper'

describe Api::JobsController do
  before(:each) do
    @preset = FactoryGirl.create(:preset)
  end

  def create_job
    @job = FactoryGirl.create(:job)
  end
  
  describe "POST 'create'" do
    describe "valid request" do
      def do_post(format=:json)
        post "create", :input => 'input', :output => 'output', :preset => 'h264', :format => format
      end
    
      it "creates jobs" do
        do_post

        job = Job.last
        job.source_file.should == 'input'
        job.destination_file.should == 'output'
        job.preset.name.should == 'h264'
        job.callback_url.should == api_job_url(job)
      end

      it "should set the state changes header" do
        do_post
        response.headers['X-State-Changes-Location'].should == api_state_changes_url(Job.last)
      end
      
      it "should set the notifications header" do
        do_post
        response.headers['X-Notifications-Location'].should == api_notifications_url(Job.last)
      end
      
      it "should redirect to /jobs if :html" do
        do_post(:html)
        response.should redirect_to(jobs_path)
      end
    end
    
    describe "invalid request" do
      def do_post(format=:json)
        post "create", :input => 'input', :preset => 'h264', :format => format
      end
      
      it "should not create jobs" do
        lambda { do_post }.should_not change(Job, :count)
      end
      
      it "should render /jobs/new if :html" do
        do_post(:html)
        response.should render_template('/jobs/new')
      end
    end
  end
  
  describe "GET 'show'" do
    before(:each) do
      create_job
      Job.stub(:find).and_return @job
    end
    
    def do_get(format=:json)
      get 'show', :id => @job.id, :format => format
    end
    
    it "shows a job as JSON" do
      do_get(:json)
      response.body.should == @job.to_json
    end

    # bug in to_xml
    # it "shows a job as XML" do
    #   do_get(:xml)
    #   response.body.should == @job.attributes.to_xml(:root => 'job')
    # end
  end
  
  describe "PUT 'update'" do
    before(:each) do
      create_job
      @job.stub(:enter)
      Job.stub(:find).and_return @job
    end
    
    def do_put
      put 'update', :id => @job.id, :status => 'status'
    end
    
    it "should find the job" do
      Job.should_receive(:find).with(@job.id.to_s)
      do_put
    end
    
    it "should enter the correct state" do
      @job.should_receive(:enter).with('status', {"status"=>"status", "id"=>@job.id.to_s, "controller"=>"api/jobs", "action"=>"update"})
      do_put
    end
  end
  
  describe "GET 'index'" do
    before(:each) do
      create_job
    end
    
    def do_get(format)
      get 'index', :format => format
    end
    
    it "shows jobs as JSON" do
      do_get(:json)
      response.body.should == Job.all.to_json
    end
    
    it "shows jobs as XML" do
      do_get(:xml)
      response.body.should == Job.all.to_xml
    end
  end
  
  describe "GET 'scheduled'" do
    before(:each) do
      create_job
      @job.update_attributes(:state => Job::Scheduled)
    end
    
    def do_get(format)
      get 'scheduled', :format => format
    end
    
    it "shows scheduled jobs as JSON" do
      do_get(:json)
      response.body.should == [@job].to_json
    end
    
    it "shows scheduled jobs as XML" do
      do_get(:xml)
      response.body.should == [@job].to_xml
    end
  end

  describe "GET 'accepted'" do
    before(:each) do
      create_job
      @job.update_attributes(:state => Job::Accepted)
      Job.stub_chain(:accepted, :order, :page).and_return [@job]
    end
    
    def do_get(format)
      get 'accepted', :format => format
    end
    
    it "shows accepted jobs as JSON" do
      do_get(:json)
      response.body.should == [@job].to_json
    end
    
    it "shows accepted jobs as XML" do
      do_get(:xml)
      response.body.should == [@job].to_xml
    end
  end
  
  describe "GET 'processing'" do
    before(:each) do
      create_job
      @job.update_attributes(:state => Job::Processing)
      Job.stub_chain(:processing, :order, :page).and_return [@job]
    end
    
    def do_get(format)
      get 'processing', :format => format
    end
    
    it "shows processing jobs as JSON" do
      do_get(:json)
      response.body.should == [@job].to_json
    end
    
    it "shows processing jobs as XML" do
      do_get(:xml)
      response.body.should == [@job].to_xml
    end
  end
  
  describe "GET 'on_hold'" do
    before(:each) do
      create_job
      @job.update_attributes(:state => Job::OnHold)
      Job.stub_chain(:on_hold, :order, :page).and_return [@job]
    end
    
    def do_get(format)
      get 'on_hold', :format => format
    end
    
    it "shows on hold jobs as JSON" do
      do_get(:json)
      response.body.should == [@job].to_json
    end
    
    it "shows on hold jobs as XML" do
      do_get(:xml)
      response.body.should == [@job].to_xml
    end
  end

  describe "GET 'success'" do
    before(:each) do
      create_job
      @job.update_attributes(:state => Job::Success)
    end
    
    def do_get(format)
      get 'success', :format => format
    end
    
    it "shows success jobs as JSON" do
      do_get(:json)
      response.body.should == [@job].to_json
    end
    
    it "shows success jobs as XML" do
      do_get(:xml)
      response.body.should == [@job].to_xml
    end
  end

  describe "GET 'failed'" do
    before(:each) do
      create_job
      @job.update_attributes(:state => Job::Failed)
    end
    
    def do_get(format)
      get 'failed', :format => format
    end
    
    it "shows failed jobs as JSON" do
      do_get(:json)
      response.body.should == [@job].to_json
    end
    
    it "shows failed jobs as XML" do
      do_get(:xml)
      response.body.should == [@job].to_xml
    end
  end
  
  describe "DELETE 'purge'" do
    before(:each) do
      create_job
      @job.update_attributes(:state => Job::Failed)
    end
    
    def do_delete
      delete 'purge'
    end
    
    it "should delete all failed jobs" do
      do_delete
      Job.count.should == 0
    end
    
    it "should render nothing" do
      do_delete
      response.body.should == ' '
    end
  end

  describe "POST 'retry'" do
    before(:each) do
      @job = double(Job, :enter => true)
      Job.stub(:find).and_return @job
    end
    
    def do_post
      post "retry", :id => 1
    end
    
    it "should find the job" do
      Job.should_receive(:find).with('1')
      do_post
    end
    
    it "should set the state to scheduled" do
      @job.should_receive(:enter).with(Job::Scheduled)
      do_post
    end
    
    it "should redirect to the index" do
      do_post
      response.should redirect_to(jobs_path)
    end
  end
end
