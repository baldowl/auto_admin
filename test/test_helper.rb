$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'test/unit'
RAILS_ENV = "test"
rails_root = ARGV.shift || File.expand_path(File.join(File.dirname(__FILE__), '../../../..'))
require "#{rails_root}/config/environment.rb"
require 'action_controller/test_process'
require 'dispatcher'
require 'breakpoint'

class Test::Unit::TestCase
  def to_test!
    assert true, "TODO test - test not implemented"
  end
  def todo!
    assert true, "TODO test - functionality not implemented"
  end

  def reset!
    reset_app!
    reset_config!
  end
  def reset_app!
    Dispatcher.reset_application!
  end
  def reset_config!
    AutoAdmin.config do |cfg|
      cfg.set_site_info 'http://example.example/', 'Example', 'eg-admin'
      cfg.primary_objects = []
      cfg.theme = AutoAdmin::AutoAdminConfiguration::DefaultTheme
    end
  end
  def disallow_class_creation!
    # We don't expect any of the following to be created, so complain
    # loudly if they are.
    [Film, Feature, Actor, Rental, City, Customer, Payment, Address].each do |c|
      c.instance_eval do
        def self.new *a; raise "#{self}.new"; end
        def self.find *a; raise "#{self}.find"; end
        def initialize *a; raise "#{self.class}#initialize"; end
      end
    end
  end

  def with_empty_classes *klasses
    klasses.each { |klass| Object.const_set klass, Class.new }
    yield
    klasses.each { |klass| Object.instance_eval { remove_const klass } }
  end
  def with_dummy_classes *klasses
    yield *klasses.map { |klass| Object.const_set klass, Object.const_get( "Dummy#{klass}" ) }
    klasses.each { |klass| Object.instance_eval { remove_const klass } }
  end
end

class DummyUser
  class << self
    attr_accessor :users
    def magic_key( un, pw ) "#{un}(*)#{pw}" end
    def register_user u
      (self.users ||= {})[magic_key(u.username,u.password)] = u
    end
    def find_by_username_and_password un, pw
      (self.users ||= {})[magic_key(un,pw)]
    end
  end
  def initialize user, pass
    @username, @password = user, pass
  end
  attr_accessor :username, :password
end

class ActionController::Base
  def rescue_action(e) raise e end
end

