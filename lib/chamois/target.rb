
module Chamois
  class Target
    private

    def filter(files, rule)
      rule_escaped = Regexp.escape(rule).gsub('*', '.*?')
      rule_regexp = /^#{rule_escaped}/

      files.select { |f| (f.match(rule_regexp)) }.to_set
    end

    # Return set of all files that match rules in given ruleset
    #
    # If there are only include rules, start with empty set
    # and add files that match rules
    #
    # If there are also exclude rules, start with all files,
    # exclude ones that match exclude rules and after that add
    # all files that match include rules
    def matching_files(all_files, ruleset)
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

    # Get current release or '.' if there's no other release
    def current_release
      return '.' unless @session.exists?('current')
      @session.read_link('current')
    end

    # Get last release that was deployed,
    # whether it is currently used or not
    def top_release
      releases = @session.read_dir('releases')
      return nil if releases.length == 0
      releases.max { |a, b| a.name <=> b.name }.name
    end

    def release_path(p, release)
      'releases/' + release + '/' + p
    end

    public

    def initialize(remote)
      @session = remote
    end

    def disconnect
      @session.disconnect
    end

    def deploy(release, files, rules_config)
      fail 'Release already exists' if @session.exists?('releases/' + release + '/')

      # get files to deploy
      if @session.rules.empty?
        deploy_files = files.to_set
        Msg.info('No rules set for this target, uploading all files')
      else
        deploy_files = Set.new
        @session.rules.each do |rule|
          fail "Rule #{rule} is not defined" unless rules_config.key? rule
          deploy_files.merge matching_files(files, rules_config[rule])
        end
      end

      fail 'No files to deploy' if deploy_files.empty?

      # check if releases folder exists
      @session.make_dir('releases/') unless @session.exists?('releases/')

      release_dir = 'releases/' + release + '/'
      @session.make_dir(release_dir)

      # upload files
      @session.upload(deploy_files, release_dir)

      # write .chamois file
      cham_file = current_release + "\n" + `git rev-parse HEAD`.strip + "\n"
      @session.make_file(release_dir + '.chamois', cham_file)

      Msg.ok("Deploy to #{@session.name} complete")
    end

    def release
      rls = top_release
      fail 'No release found' if rls.nil?

      if rls == current_release
        Msg.info("#{@session.name} currently at last release")
        return
      end

      Msg.info("Releasing #{rls} at #{@session.name}")
      @session.make_link!('current', 'releases/' + rls + '/')
      Msg.ok("Release at #{@session.name} complete")
    end

    def rollback
      fail "Can't roll back, no release found" unless @session.exists?('current/.chamois')

      cham = @session.read_file('current/.chamois')
      prev_release = cham.split("\n")[0]
      fail "Can't roll back, currently at first release" if prev_release == '.'

      Msg.info("Rolling #{@session.name} back to release " + prev_release)
      @session.make_link!('current', 'releases/' + prev_release)
      Msg.ok("Rollback at #{@session.name} complete")
    end
  end
end
