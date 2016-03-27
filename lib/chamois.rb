require 'thor'
require 'chamois/application'
require 'chamois/setup'

class ChamoisCLI < Thor
  private

  def run(stage)
    app = Chamois::Application.new(stage)
    if app.connect
      yield app
      app.disconnect
    end
  end

  public

  desc 'init', 'Starts initial setup'
  def init()
    setup = Chamois::Setup.new()
    setup.setup
  end

  desc 'deploy STAGE', 'Deploy given stage to all targets'
  def deploy(stage)
    run(stage, &:deploy)
  end

  desc 'dp STAGE', 'Deploy alias'
  def dp(stage)
    deploy(stage)
  end

  desc 'release STAGE', 'Set last deployed release as current release at given stage'
  def release(stage)
    run(stage, &:release)
  end

  desc 'rl STAGE', 'Release alias'
  def rl(stage)
    release(stage)
  end

  desc 'rollback STAGE', 'Rollback to previously used relese at given stage'
  def rollback(stage)
    run(stage, &:rollback)
  end

  desc 'rb STAGE', 'Rollback alias'
  def rb(stage)
    rollback(stage)
  end
end

ChamoisCLI.start(ARGV)
