#!/usr/bin/env ruby
require_relative '../lib/chamois/target'
require_relative '../lib/chamois/remote'
require_relative '../lib/chamois/msg'
require_relative 'spec_helper'

describe Chamois::Target do
  
  let!(:remote_mock) { instance_double("Chamois::Remote") }
  subject(:c) { described_class.new(remote_mock) }

  let(:release) { '01' }
  let(:files) do
    [
      'api/endpoint.rb',
      'classes/core/base.rb',
      'bootloader.rb'
    ]
  end
  let(:rules) do
    {}
  end

  before(:each) do
    allow(remote_mock).to receive(:name) { 'test' }
  end

  describe 'Deployment' do
    it 'Deploys without rules' do
      
      # checks whether release exists
      expect(remote_mock).to receive(:exists?).with('releases/01/') { false }

      # creates release folder
      expect(remote_mock).to receive(:exists?).with('releases/') { true }
      expect(remote_mock).to receive(:make_dir).with('releases/01/')

      # call upload
      expect(remote_mock).to receive(:upload).with(files.to_set, 'releases/01/')

      # create .chamois file
      expect(c).to receive(:current_release) { '.' }
      expect(c).to receive(:`).with('git rev-parse HEAD').and_return("git_HEAD_hash\n")
      expect(remote_mock).to receive(:make_file).with('releases/01/.chamois', ".\ngit_HEAD_hash\n")

      # print status
      expect(remote_mock).to receive(:name).and_return('test')
      expect { c.deploy(release, files, rules) }.to output.to_stdout
    end
  end

  describe 'Release' do
    it 'Releases' do
      expect(c).to receive(:top_release).and_return('02')
      expect(c).to receive(:current_release).and_return('01')
      expect(remote_mock).to receive(:make_link!).with('current', 'releases/02/')
      expect { c.release }.to output(/Release at test complete/).to_stdout
    end

    it 'Detects there\'s no new release' do
      expect(c).to receive(:top_release).and_return('02')
      expect(c).to receive(:current_release).and_return('02')
      expect { c.release }.to output(/currently at last release/).to_stdout
    end

    it 'Fails to release when no release found' do
      expect(c).to receive(:top_release).and_return(nil)
      expect { c.release }.to raise_error(RuntimeError)
    end
  end

  describe 'Rollback' do

    it 'Fails to rollback when no release found' do
      expect(remote_mock).to receive(:exists?) { false }
      expect { c.rollback }.to raise_error(RuntimeError)
    end

    it 'Fails to rollback when first relase' do
      expect(remote_mock).to receive(:exists?) { true }
      expect(remote_mock).to receive(:read_file) { ".\ngit_HEAD_hash\n" }
      expect { c.rollback }.to raise_error(RuntimeError)
    end

    it 'Rolls back' do
      expect(remote_mock).to receive(:exists?) { true }
      expect(remote_mock).to receive(:read_file) { "01\ngit_HEAD_hash\n" }
      expect(remote_mock).to receive(:make_link!).with('current', 'releases/01')
      
      expect { c.rollback }.to output(/Rollback at test complete/).to_stdout
    end
  end
  
end
