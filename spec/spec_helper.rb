$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '../lib'))

# require 'pry'; binding.pry
require 'stapfen'
require 'rspec/its'

is_java = (RUBY_PLATFORM == 'java')

unless is_java
  require 'debugger'
  require 'debugger/pry'
end


RSpec.configure do |c|
  c.color = true
  c.order = "random"

  unless is_java
    c.filter_run_excluding :java => true
  end
end
