%w(functional helper configuration label routing).each do |file|
  require File.dirname(__FILE__) + "/#{file}_tests"
end

