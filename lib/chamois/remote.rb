
module Chamois
  class Remote


  private

    def rtrim(p)
      p.strip.gsub(/\/*$/, '')
    end

    def release_path(p, release)
      'releases/' + release + '/' + p
    end

    def path(p, release=nil)
      return @root + release_path(p, release) if release
      @root + p
    end

  public

    attr_reader :rules, :name

    def initialize(name, config)
      @name = name

      options = {}
      options[:port] = config['port'] if config['port']

      @root = './'
      @root = rtrim(config['root']) + '/' if config['root']

      @rules = {}
      @rules = config['rules'] if config['rules']

      @sess = Net::SSH.start(config['host'], config['user'], options)

      Msg::ok "Connected to #{@name}"
    end

    def close
      @sess.close
      Msg::ok "Disconnected from #{@name}"
    end

    def check_dir(dir)
      # TODO check permissions as well
      Msg::info("#{@name}: Checking #{path dir}", " ... ")

      begin
        @sess.sftp.lstat!(path dir)
        Msg::ok
        true
      rescue Net::SFTP::StatusException => e
        Msg::fail
        false
      end
    end

    def make_dir(dir)
      Msg::info("#{@name}: Creating #{path dir}", " ... ")

      begin
        @sess.sftp.mkdir!(path dir)
        Msg::ok
        true
      rescue Net::SFTP::StatusException => e
        Msg::fail
        false
      end
    end

    def make_dir_tree(files, release)
      
      dirs = Set.new

      files.each do |f|
        p = f.split('/')
        p.pop
        
        dir_path = ''
        p.each do |d|
          dir_path += d + '/'
          dirs.add(dir_path)
        end
      end

      puts dirs.to_a.sort!

      dirs.each do |d|
        make_dir release_path(d, release)
      end
    end

    def upload(files, release)
      files.each do |f|
        Msg::info("#{@name}: Uploading #{f} to #{path f, release}", " ... ")

        if !File.exists?(f)
          Msg::fail(" SKIPPED (file does not exist)")
          next
        end

        @sess.sftp.upload!(f, path(f, release))
        Msg::ok
      end
    end

  end
end