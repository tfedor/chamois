#!/usr/bin/env ruby
require 'net/ssh'
require 'net/sftp'
require_relative '../lib/chamois/remote'
require_relative '../lib/chamois/msg'
require_relative 'spec_helper'

describe Chamois::Remote do

  subject(:r) { described_class.new(name, config) }
  let(:name) { "test" }
  let(:config) do
    {
      'host' => "server_host",
      'port' => 22,
      'user' => "server_user",
      'root' => "server/root/"
    }
  end

  let(:ssh_class_mock) { class_double("Net::SSH")
        .as_stubbed_const(:transfer_nested_constants => true) }

  let(:ssh_sess_mock) { instance_double("Net::SSH::Session") }

  describe 'Connection' do
    it 'Connects to server' do

      expect(ssh_class_mock).to receive(:start).with("server_host", "server_user", {port: 22})
      expect { r }.to output(/Connected to test/).to_stdout
    end

    it 'Disconnects from server' do

      expect(ssh_class_mock).to receive(:start).and_return(ssh_sess_mock)
      expect(ssh_sess_mock).to receive(:close)

      expect { r.close }.to output(/Disconnected from test/).to_stdout
    end
  end
end
