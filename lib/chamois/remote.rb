
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

    def exists?(pathname)
      begin
        @sess.sftp.lstat!(path pathname)
        true
      rescue Net::SFTP::StatusException => e
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

    def read_dir(dir)
      @sess.sftp.dir.entries path(dir)
    end

    def remove(p)
      @sess.sftp.remove! path p
    end

    def link!(lnk, target)
      raise "Target does not exist" unless exists?(target)
      remove(lnk) if exists?(lnk)
      @sess.sftp.symlink! target, path(lnk)
    end

    def open(p, flag)
      file = @sess.sftp.open!(p, flag)
      yield file
      @sess.sftp.close!(file)
    end

    def make_file(file, release, content)
      Msg::info("#{@name}: Writing release info", ' ... ')
      open(path(file, release), 'w') { |f| @sess.sftp.write!(f, 0, content) }
      Msg::ok
    end

    def read(file)
      content = nil
      open(path(file), 'r') do |f|
        offset = 0
        length = 1024
        content = ''
        while 1
          chunk = @sess.sftp.read!(f, offset, length)
          break unless chunk

          content += chunk
          offset += length
        end
      end
      content
    end

    def read_link(link)
      @sess.sftp.readlink!(path link).name.split("/").last
    end

  end
end