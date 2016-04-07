#!/usr/bin/env ruby
require 'set'
require 'net/ssh'
require 'net/sftp'
require 'net/sftp/errors'
require_relative '../lib/chamois/remote'
require_relative '../lib/chamois/msg'
require_relative 'spec_helper'

describe Chamois::Remote do
  subject(:r) { described_class.new(name, config) }
  let(:name) { 'test' }
  let(:config) do
    {
      'host' => 'server_host',
      'port' => 22,
      'user' => 'server_user',
      'root' => 'server/root/'
    }
  end

  let!(:ssh_class_mock) { class_double('Net::SSH').as_stubbed_const(transfer_nested_constants: true) }
  let!(:ssh_sess_mock) { instance_double('Net::SSH::Session') }
  let!(:sftp_sess_mock) { instance_double('Net::SFTP::Session') }

  before(:each) do
    expect(ssh_class_mock)
      .to receive(:start).with('server_host', 'server_user', port: 22)
      .and_return(ssh_sess_mock)

    allow(ssh_sess_mock)
      .to receive(:sftp)
      .and_return(sftp_sess_mock)

    expect { r }.to output(/Connected to test/).to_stdout
  end

  describe 'Connection' do
    it 'Disconnects' do
      expect(ssh_sess_mock).to receive(:close)
      expect { r.disconnect }.to output(/Disconnected from test/).to_stdout
    end
  end

  describe 'Helper methods' do
    it 'Strips the whitespace and forward slashes' do
      expect(r.instance_eval { rtrim('path/to/folder///') }).to match('path/to/folder')
      expect(r.instance_eval { rtrim('path/to/folder  ') }).to match('path/to/folder')
      expect(r.instance_eval { rtrim('path/to/folder / ') }).to match('path/to/folder')
      expect(r.instance_eval { rtrim('path/to/folder// ') }).to match('path/to/folder')
    end

    it 'Returns full path from user\'s root' do
      expect(r.instance_eval { path('path/to/folder') }).to match('server/root/path/to/folder')
    end
  end

  describe 'Symlink' do
    before(:each) do
      resp_mock = instance_double('Net::SFTP::Response')
      allow(resp_mock).to receive(:code)
      allow(resp_mock).to receive(:message)

      allow(sftp_sess_mock).to receive(:lstat!) do |path|
        fail Net::SFTP::StatusException, resp_mock unless path == 'server/root/test' || path == 'server/root/correct/target'
      end
    end

    it 'Checks if file exists' do
      expect(sftp_sess_mock).to receive(:lstat!).with('server/root/test')
      expect(r.exists? 'test').to be true

      expect(sftp_sess_mock).to receive(:lstat!).with('server/root/folder/file.rb')
      expect(r.exists? 'folder/file.rb').to be false
    end

    it 'Makes link' do
      expect(sftp_sess_mock).to receive(:symlink!).with('correct/target', 'server/root/new_link')
      r.make_link!('new_link', 'correct/target')
    end

    it 'Replaces link' do
      expect(sftp_sess_mock).to receive(:remove!).with('server/root/test')
      expect(sftp_sess_mock).to receive(:symlink!).with('correct/target', 'server/root/test')
      r.make_link!('test', 'correct/target')
    end

    it 'Checks link target exists' do
      expect { r.make_link!('test', 'incorrect/target') }.to raise_error(RuntimeError)
    end

    it 'Reads link correctly' do
      name_mock = instance_double('Net::SFTP::Protocol::V01::Name')
      allow(name_mock).to receive(:name) { 'path/to/link/target' }

      expect(sftp_sess_mock).to receive(:readlink!).with('server/root/link').and_return(name_mock)
      expect(r.read_link 'link').to match('target')
    end
  end

  describe 'Upload' do
    let(:files) do
      {
        'modules/classA/file1.rb' => 'modules/classA_file1.rb',
        'modules/classA/file2.rb' => 'modules/classA_file2.rb',
        'modules/classA/file3.rb' => 'modules/classA_file3.rb',
        'modules/classB/some_class.rb' => 'modules/classB_some_class.rb',
        'api/endpoint.rb' => 'api/endpoint.rb',
        'api/query.rb' => 'api/query.rb',
        '.gitignore' => '.gitignore',
        'some/very/long/path/to/dir/file' => 'some/very/long/path/to/dir/file',
        'some/files.rb' => 'some/files.rb',
        'logs/2016.txt' => 'logs/2016.txt',
        'logs/2015.txt' => 'logs/2015.txt',
        'logs/2014.txt' => 'logs/2014.txt',
        'logs/2013.txt' => 'logs/2013.txt',
      }
    end

    it 'Ensures directories exist' do
      expect(r).to receive(:exists?).exactly(9).times do |arg|
        arg == 'releases/01/logs/'
      end

      expect(r).to receive(:make_dir).with('releases/01/modules/')
      expect(r).to receive(:make_dir).with('releases/01/api/')
      expect(r).to receive(:make_dir).with('releases/01/some/')
      expect(r).to receive(:make_dir).with('releases/01/some/very/')
      expect(r).to receive(:make_dir).with('releases/01/some/very/long/')
      expect(r).to receive(:make_dir).with('releases/01/some/very/long/path/')
      expect(r).to receive(:make_dir).with('releases/01/some/very/long/path/to/')
      expect(r).to receive(:make_dir).with('releases/01/some/very/long/path/to/dir/')

      list = files
      r.instance_eval { ensure_dirs(list.values, 'releases/01') }
    end

    it 'Uploads files' do
      # ensure dirs is properly called
      expect(r).to receive(:ensure_dirs).with(files.values, 'releases/01')

      # all files locally exist
      file_mock = class_double('File').as_stubbed_const(transfer_nested_constants: true)
      allow(file_mock).to receive(:exist?) { true }

      # upload! is called for each file with correct folder prepended
      files.each do |local, remote|
        expect(sftp_sess_mock).to receive(:upload!).with(local, 'server/root/releases/01/' + remote)
      end

      expect { r.upload(files, 'releases/01') }.to output.to_stdout
    end
  end
end
