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
  class ConfigurationError < StandardError
  end
  class ConsumeError < StandardError
  end
  class InvalidMessageError < StandardError
  end
end
