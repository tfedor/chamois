
module Chamois
  class Target

  private

    def filter(files, rule)
      rule_escaped = Regexp.escape(rule).gsub("\\*", ".*?")
      rule_regexp = /^#{rule_escaped}/

      files.select { |f| (f.match(rule_regexp)) }.to_set
    end

    def files_ruleset(all_files, ruleset)
      files = Set.new

      if ruleset.key? 'exclude'
        files = all_files.to_set

        ruleset['exclude'].each do |rule|
          files.subtract filter(all_files, rule)
        end
      end

      if ruleset.key? 'include'
        ruleset['include'].each do |rule|
          files.merge filter(all_files, rule)
        end
      end

      files
    end

  public

    def initialize(remote)
      @session = remote
    end

    def disconnect
      @session.close
    end

    def deploy(files, rules_config)
      # get files to deploy
      deploy_files = Set.new

      @session.rules.each do |rule|
        raise "Rule #{rule} is not defined" unless rules_config.key? rule
        deploy_files.merge files_ruleset(files, rules_config[rule])
      end

      # check if remote folders exist
      @session.make_dir("releases/") unless @session.check_dir("releases/")

      release = Time.now.strftime("%Y-%m-%d_%H%M%S.%L").to_s
      release_dir = 'releases/' + release + '/'
      @session.make_dir(release_dir)

      # create dir tree
      @session.make_dir_tree(deploy_files, release)

      # upload files
      @session.upload(deploy_files, release)

      Msg::ok("Deploy to #{@session.name} complete")
    end

    def release
    end

    def rollback
    end
  end
end