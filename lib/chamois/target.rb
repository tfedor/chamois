
module Chamois
  class Target

  private

    def filter(files, rule)
      rule_escaped = Regexp.escape(rule).gsub("\\*", ".*?")
      rule_regexp = /^#{rule_escaped}/

      files.select { |f| (f.match(rule_regexp)) }.to_set
    end

    def files(all_files, ruleset)
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

    def current_release
      return '.' unless @session.exists?('current')
      @session.read_link('current')
    end

    def top_release
      releases = @session.read_dir('releases')
      return nil if releases.length == 0
      releases.max { |a, b| a.name <=> b.name }.name
    end

  public

    def initialize(remote)
      @session = remote
    end

    def disconnect
      @session.close
    end

    def deploy(release, files, rules_config)

      raise "Release already exists" if @session.exists?('releases/' + release + '/')

      # check if releases folder exists
      @session.make_dir("releases/") unless @session.exists?("releases/")

      release_dir = 'releases/' + release + '/'
      @session.make_dir(release_dir)

      # TODO should probably move to Remote, since it holds rules anyway
      # get files to deploy
      deploy_files = Set.new

      @session.rules.each do |rule|
        raise "Rule #{rule} is not defined" unless rules_config.key? rule
        deploy_files.merge files(files, rules_config[rule])
      end

      # create dir tree
      @session.make_dir_tree(deploy_files, release)

      # upload files
      @session.upload(deploy_files, release)

      # write .chamois file
      cham_file = current_release + "\n" + `git rev-parse HEAD`.strip + "\n"
      @session.make_file(".chamois", release, cham_file)

      Msg::ok("Deploy to #{@session.name} complete")
    end

    def release
      rls = top_release
      raise "No release found" if rls.nil?

      Msg::info("Releasing #{rls} at #{@session.name}")
      @session.link!('current', 'releases/' + rls + '/')
      Msg::ok("Release at #{@session.name} complete")
    end

    def rollback
      raise "Can't roll back, no release found" unless @session.exists?('current/.chamois')

      cham = @session.read('current/.chamois')
      prev_release = cham.split("\n")[0]
      raise "Can't roll back, currently at first release" if prev_release == '.'

      Msg::info("Rolling #{@session.name} back to release " + prev_release)
      @session.link!('current', 'releases/' + prev_release)
      Msg::ok("Rollback at #{@session.name} complete")
    end
  end
end