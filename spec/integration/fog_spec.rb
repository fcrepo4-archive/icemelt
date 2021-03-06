require 'spec_helper'
require 'fog'

describe "Fog Integration Spec", :acceptance => true do
  before(:all) do
  	begin
      vault = subject.vaults.get 'myvault'
      vault.destroy
    rescue => e
      puts e.inspect
    end
  end

  subject { Fog::AWS::Glacier.new :aws_access_key_id => '', :aws_secret_access_key => '', :scheme => 'http', :host => 'localhost', :port => '3000'}

  it "should create vaults" do
  	subject.vaults.create :id => 'myvault'
  end

  it "should destroy vaults" do
    vault = subject.vaults.create :id => 'myvaultabc'
    vault.destroy
    subject.vaults.get(vault.id).should be_nil
  end

  it "should describe vaults" do
    subject.describe_vault('myvault').body['VaultName'].should == 'myvault'
  end

  it "should list vault" do
    subject.vaults.should have(1).item
    subject.vaults.should 
  end

  it "should do single-part uploads" do
    subject.vaults.create :id => 'myvaultwithcontent'
    subject.create_archive('myvaultwithcontent', 'data body')
  end

  it "should add archives to vaults" do
    vault = subject.vaults.get 'myvault'

    vault.archives.create :body => 'asdfgh', :multipart_chunk_size => 1024*1024
  end

  it "should create multipart archives" do
    vault = subject.vaults.create :id => 'myvaultabc'
    body = StringIO.new(`openssl rand 2097152`)
    body.rewind
    archive = vault.archives.create(:body => body, :multipart_chunk_size => 1024*1024)
    
    job = vault.jobs.create :type => Fog::AWS::Glacier::Job::INVENTORY

    job.wait_for {ready?}

    json = job.get_output.body
    json['ArchiveList'].select { |x| x['ArchiveId'] == archive.id }.first['Size'].should == 2*1024*1024

    body.rewind

    job = vault.jobs.create(:type => Fog::AWS::Glacier::Job::ARCHIVE, :archive_id => archive.id)

    job.wait_for {ready?}

    body.rewind
    job.get_output.body.force_encoding('ASCII').should == body.read.force_encoding('ASCII')

    archive.destroy
    vault.destroy
  end


  it "should list inventories" do
    vault = subject.vaults.get 'myvault'

    job = vault.jobs.create :type => Fog::AWS::Glacier::Job::INVENTORY

    job.wait_for {ready?}

    json = job.get_output.body

    json['ArchiveList'].should have_at_least(1).archive
  end

  it "should retrieve content" do
    vault = subject.vaults.get 'myvault'

    archive = vault.archives.create :body => 'asdfgh', :multipart_chunk_size => 1024*1024

    job = vault.jobs.create(:type => Fog::AWS::Glacier::Job::ARCHIVE, :archive_id => archive.id)

    job.wait_for {ready?}

    job.get_output.body.should == 'asdfgh'
  end
end