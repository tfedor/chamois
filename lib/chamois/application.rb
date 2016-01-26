
require 'yaml'
require 'set'
require 'net/ssh'
require 'net/scp'
require 'net/sftp'
require_relative 'target'
require_relative 'remote'
require_relative 'msg'

module Chamois  
  class Application

  private

    def files
      git_branch = `git symbolic-ref --short HEAD`.strip
      git_files = `git ls-tree -r #{git_branch} --name-only`.split("\n")

      git_files.each do |file|
        file.strip!
      end

      git_files
    end

    def read_config(path)
      y = File.read(path)

      begin
        config = YAML.load(y)
      rescue
        raise "Incorrect format of config file at #{path}"
      end
      config
    end

    def load_config!(path)
      raise "Can't find config at #{path}" unless File.exists?(path)
      raise "Can't read config file at #{path}" unless File.readable?(path)
      read_config(path)
    end

    def load_config(path)
      return {} unless File.exists?(path) and File.readable?(path)
      read_config(path)
    end

  public

    def initialize(stage)
      stages = load_config!('_deploy/stages.yaml')
      @stage = stages[stage]
      raise "Unknown stage" unless @stage

      @targets = []
    end

    # Create connection to target and ready for commands
    def connect
      @stage.each do |name, config|
        begin
          remote = Remote.new(name, config)
          @targets.push Target.new(remote)
        rescue Exception => e
          Msg::fail e
          disconnect
          return false
        end
      end
      true
    end

    # Disconnect all targets
    def disconnect
      @targets.each { |c| c.disconnect }
    end

    def deploy
      rules_config = load_config('_deploy/rules.yaml')

      release = Time.now.strftime("%Y-%m-%d_%H%M%S.%L").to_s

      begin
        @targets.each { |t| t.deploy(release, files, rules_config) }
        Msg::ok("Deploy complete")
      rescue Exception => e
        Msg::fail e
      end
    end

    def release
      begin
        @targets.each { |t| t.release }
        Msg::ok("Release complete")
      rescue Exception => e
        Msg::fail e
        Msg::fail("WARNING! May be at inconsistent state!")
      end
    end

    def rollback
      begin
        @targets.each { |t| t.rollback }
        Msg::ok("Rollback complete")
      rescue Exception => e
        Msg::fail e
        Msg::fail("WARNING! May be at inconsistent state!")
      end
    end
  end
end
