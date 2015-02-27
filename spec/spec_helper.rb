$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '../lib'))

# require 'pry'; binding.pry
require 'stapfen'
require 'rspec/its'

is_java = (RUBY_PLATFORM == 'java')

if is_java
  require 'hermann/consumer'
end

RSpec.configure do |c|
  c.color = true
  c.order = "random"

  unless is_java
    c.filter_run_excluding :java => true
  end
end
