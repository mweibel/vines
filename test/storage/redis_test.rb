# encoding: UTF-8

require 'storage_tests'
require 'vines'
require 'minitest/autorun'

class RedisTest < MiniTest::Unit::TestCase
  include StorageTests

  MOCK_REDIS = Class.new do
    def initialize
      @db = {}
    end
    def del(key)
      @db.delete(key)
      EM.next_tick { yield if block_given? }
    end
    def get(key)
      EM.next_tick { yield @db[key] }
    end
    def set(key, value)
      @db[key] = value
      EM.next_tick { yield if block_given? }
    end
    def hget(key, field)
      EM.next_tick { yield @db[key][field] rescue nil }
    end
    def hgetall(key)
      EM.next_tick { yield @db[key] || {} }
    end
    def hset(key, field, value)
      @db[key] ||= {}
      @db[key][field] = value
      EM.next_tick { yield if block_given? }
    end
    def hmset(key, *args)
      @db[key] = Hash[*args]
      EM.next_tick { yield if block_given? }
    end
    def flushdb
      @db.clear
      EM.next_tick { yield if block_given? }
    end
  end.new

  def setup
    EMLoop.new do
      db = MOCK_REDIS
      db.set('user:empty@wonderland.lit', {}.to_json)
      db.set('user:no_password@wonderland.lit', {'foo' => 'bar'}.to_json)
      db.set('user:clear_password@wonderland.lit', {'password' => 'secret'}.to_json)
      db.set('user:bcrypt_password@wonderland.lit', {'password' => BCrypt::Password.create('secret')}.to_json)
      db.set('user:full@wonderland.lit', {
        'password' => BCrypt::Password.create('secret'),
        'name' => 'Tester'
      }.to_json)
      db.hmset('roster:full@wonderland.lit', 
        'contact1@wonderland.lit',
        {'name' => 'Contact1', 'groups' => %w[Group1 Group2]}.to_json,
        'contact2@wonderland.lit',
        {'name' => 'Contact2', 'groups' => %w[Group3 Group4]}.to_json)
      db.set('vcard:full@wonderland.lit', {'card' => VCARD.to_xml}.to_json)
      db.hset('fragments:full@wonderland.lit', FRAGMENT_ID, {'xml' => FRAGMENT.to_xml}.to_json)
    end
  end

  def teardown
    MOCK_REDIS.flushdb
  end

  def storage
    storage = Vines::Storage::Redis.new { host 'localhost'; port 6397 }
    def storage.redis; RedisTest::MOCK_REDIS; end
    storage
  end

  def test_init_raises_no_errors
    EMLoop.new do
      Vines::Storage::Redis.new {}
      Vines::Storage::Redis.new { host 'localhost' }
      Vines::Storage::Redis.new { host'localhost'; port '6379' }
    end
  end
end
