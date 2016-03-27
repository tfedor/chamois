require 'yaml'
require_relative 'msg'

module Chamois
  class Setup
    def setup
      if Dir.exist? '_deploy'
        if File.exist? '_deploy/stages.yaml' or File.exist? '_deploy/rules.yaml'
          Msg.fail('It seems like you have already set Chamois up.')
          Msg.fail('Do you want to rewrite your current setup? (y/n) ', '')
          confirm = STDIN.gets
          return if confirm[0] != 'n'
        end
      else
        Dir.mkdir '_deploy'
      end

      setup = {}
      rules = {}

      Msg.ok "1. Let's setup stages first. Stage should be one item in your development cycle."
      Msg.ok "For example, you may have stages 'development', 'ready' and 'production'."
      Msg.ok "List names of stages you will want to use, separate each stage with space:"
      print '> '
      begin
        stages = Array(STDIN.gets.strip!.split(/\s+/))
      end until stages.length != 0

      puts ''
      Msg.ok '2. Now you will setup targets for individual stages. Targets are individual devices'
      Msg.ok 'you will deploy to. You will use their names in rules definition.'

      stages.each do |stage|
        setup[stage] = {}

        Msg.ok 'STAGE ' + stage
        Msg.ok "List targets's names, separate by space:"
        print '> '
        begin
          targets = Array(STDIN.gets.strip!.split(/\s+/))
        end until targets.length != 0

        targets.each do |target|
          setup[stage][target] = {}
          rules[target] = {}

          puts ''
          puts 'TARGET ' + stage + ':' + target
          print 'host: '
          setup[stage][target]['host'] = STDIN.gets.strip!

          print 'port: '
          setup[stage][target]['port'] = STDIN.gets.strip!

          print 'user: '
          setup[stage][target]['user'] = STDIN.gets.strip!

          print 'root: '
          setup[stage][target]['root'] = STDIN.gets.strip!
        end

        puts ''
      end

      File.open('_deploy/stages.yaml', 'w') do |f|
        f.write setup.to_yaml
      end

      File.open('_deploy/rules.yaml', 'w') do |f|
        f.write setup.to_yaml
      end
    end
  end
end
