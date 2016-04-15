
module Chamois
  class Target
    private

    def rule_regexp(rule)
      rule_escaped = Regexp.escape(rule).gsub('\\*', '.*?')

      if rule_escaped[0] == '/'
        rule_escaped.sub!(/^\//, '(^|/)')
      else
        rule_escaped = '^' + rule_escaped
      end

      /#{rule_escaped}/
    end

    def filter(files, rule)
      files.select { |f| (f.match rule_regexp(rule)) }.to_set
    end

    # Return set of all files that match rules in given ruleset
    #
    # If there are only include rules, start with empty set
    # and add files that match rules
    #
    # If there are also exclude rules, start with all files,
    # exclude ones that match exclude rules and after that add
    # all files that match include rules
    def matching_files(all_files, rules)
      files = Set.new

      files = all_files.to_set if rules['exclude'].length != 0

      rules['exclude'].each { |rule| files.subtract filter(all_files, rule) }
      rules['include'].each { |rule| files.merge    filter(all_files, rule) }

      files
    end

    def deploy_map(files, rules)
      deploy_map = {}

      files.each do |f|
        rules.each do |rule_match, rule_replace|
          regexp_match = rule_regexp(rule_match)
          next unless f.match regexp_match

          deploy_map[f] = f.gsub(regexp_match, rule_replace)
        end

        deploy_map[f] = f unless deploy_map.key? f
      end

      deploy_map
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
      required_dirs = {}

      if @session.rules.empty?
        deploy_files = deploy_map(files.to_set, {})
        Msg.info('No rules set for this target, uploading all files')
      else
        rules = {
          'exclude' => [],
          'include' => [],
          'rename' => {},
        }

        @session.rules.each do |rule|
          fail "Rule #{rule} is not defined" unless rules_config.key? rule
          ruleset = rules_config[rule]
          rules['exclude'].concat ruleset['exclude'] if ruleset.key? 'exclude'
          rules['include'].concat ruleset['include'] if ruleset.key? 'include'
          rules['include'].concat ruleset['rename'].keys if ruleset.key? 'rename'
          rules['rename'].merge! ruleset['rename'] if ruleset.key? 'rename'
          required_dirs.merge!  ruleset['dirs'] if ruleset.key? 'dirs'
        end

        deploy_files = deploy_map(matching_files(files, rules), rules['rename'])
      end

      fail 'No files to deploy' if deploy_files.empty?

      # check if releases folder exists
      @session.make_dir('releases/') unless @session.exists?('releases/')

      release_dir = 'releases/' + release + '/'
      @session.make_dir(release_dir)

      # make required dirs with correct permissions
      required_dirs.each do |d, p|
        @session.make_dir(release_dir + d, {permissions: p})
      end

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
