require 'colorize'

module Chamois
  class Msg
    def self.ok(message = 'OK', eos = "\n")
      print message.to_s.green + eos
    end

    def self.fail(message = 'FAIL', eos = "\n")
      print message.to_s.red + eos
    end

    def self.info(message, eos = "\n")
      print message.to_s + eos
    end
  end
end
