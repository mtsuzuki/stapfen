begin
  require 'stomp'
rescue LoadError
  # Can't process Stomp
end

begin
  require 'java'
  require 'jms'
rescue LoadError
  # Can't process JMS
end

require 'stapfen/version'
require 'stapfen/client'
require 'stapfen/worker'

module Stapfen
  class ConfigurationError < StandardError; end
  class ConsumeError < StandardError; end
  class InvalidMessageError < StandardError; end

  def self.logger=(instance)
    @logger = instance
  end

  def self.logger
    @logger ||= default_logger
  end

  private

  def self.default_logger
    require 'logger'
    Logger.new(STDOUT)
  end
end
