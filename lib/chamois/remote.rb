
module Chamois
  class Remote
    private

    # Trim whitespace from beginning and end
    # and forward slashes from end of the path
    def rtrim(p)
      p.strip.gsub(%r{/*\s*$}, '')
    end

    def path(p)
      @root + p
    end

    # Ensure that all directories used in files' paths are created
    # in correct directory
    def ensure_dirs(files, target_dir)
      target = rtrim(target_dir) + '/'

      dirs = Set.new # use to prevent more expensive check
      files.each do |f|
        p = f.split('/')
        p.pop

        dir = target
        p.each do |d|
          dir += d + '/'

          next if dirs.include? dir
          make_dir dir unless exists? dir
          dirs.add(dir)
        end
      end
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

      Msg.ok "Connected to #{@name}"
    end

    def disconnect
      @sess.close
      Msg.ok "Disconnected from #{@name}"
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
      Msg.info("#{@name}: Creating #{path dir}", ' ... ')

      begin
        @sess.sftp.mkdir!(path dir)
        Msg.ok
      rescue Net::SFTP::StatusException => e
        Msg.fail
      end
    end

    def make_file(file, content)
      Msg.info("#{@name}: Writing release info", ' ... ')
      open(path(file), 'w') { |f| @sess.sftp.write!(f, 0, content) }
      Msg.ok
    end

    def make_link!(lnk, target)
      fail 'Symlink target does not exist' unless exists?(target)
      remove(lnk) if exists?(lnk)
      @sess.sftp.symlink! target, path(lnk)
    end

    def remove(p)
      @sess.sftp.remove! path(p)
    end

    def open(p, flag)
      file = @sess.sftp.open!(p, flag)
      yield file
      @sess.sftp.close!(file)
    end

    def read_file(file)
      content = nil
      open(path(file), 'r') do |f|
        offset = 0
        length = 1024
        content = ''
        loop do
          chunk = @sess.sftp.read!(f, offset, length)
          break unless chunk

          content += chunk
          offset += length
        end
      end
      content
    end

    def read_dir(dir)
      @sess.sftp.dir.entries path(dir)
    end

    def read_link(link)
      @sess.sftp.readlink!(path link).name.split('/').last
    end

    def upload(files, dir)
      ensure_dirs(files.values, dir)

      files.each do |local, remote|
        target = path(rtrim(dir) + '/' + remote)
        Msg.info("#{@name}: Uploading #{local} to #{target}", ' ... ')

        unless File.exist?(local)
          Msg.fail(' SKIPPED (file does not exist)')
          next
        end

        @sess.sftp.upload!(local, target)
        Msg.ok
      end
    end
  end
end
