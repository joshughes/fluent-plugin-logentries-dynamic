require 'helper'

class LogentriesOutputTest < Test::Unit::TestCase
  def setup
    unless defined?(Fluent::Filter)
      omit('Fluent::Filter is not defined. Use fluentd 0.12 or later.')
    end

    Fluent::Test.setup
  end

  CONFIG = %[
    cache_size 2000
    cache_ttl 300
    api_token foobar
    use_ssl false
    logset_name_field namespace
    log_name_field container_name
    log_set_name_remove remove-me-
  ]

  def stub_log_create
    file = File.open("test/logentries/new_log.json", 'rb')
    stub_request(:post, "https://rest.logentries.com/management/logs").
      with(headers: {'X-Api-Key'=>'foobar'}).
      to_return(status: 200, body: file, headers: {})
  end

  def stub_log_post(log_token)
    stub_request(:post, "https://webhook.logentries.com/noformat/logs/#{log_token}").
      with(headers: {'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
        to_return(status: 204, body: "", headers: {})
  end

  def stub_logset_create(name)
    file = File.open("test/logentries/new_log_set.json", 'rb')
    stub_request(:post, "https://rest.logentries.com/management/logsets").
    with(body: "{\"logset\":{\"name\":\"#{name}\"}}",
         headers: {'X-Api-Key'=>'foobar'}).
    to_return(status: 200, body: file, headers: {})
  end

  def stub_logsets
    file = File.open("test/logentries/logsets.json", 'rb')
    stub_request(:get, "https://rest.logentries.com/management/logsets").
      to_return(status: 200, body: file, headers: {})
  end

  def stub_logset(logset_id)
    file = File.open("test/logentries/logset.json", 'rb')
    stub_request(:get, "https://rest.logentries.com/management/logsets/#{logset_id}").
      to_return(status: 200, body: file, headers: {})
  end

  def stub_log(log_id)
    file = File.open("test/logentries/#{log_id}.json", 'rb')
    stub_request(:get, "https://rest.logentries.com/management/logs/#{log_id}").
      to_return(status: 200, body: file, headers: {})
  end

  def create_driver(conf = CONFIG, tag = 'test')
    Fluent::Test::OutputTestDriver.new(Fluent::LogentriesDynamicOutput, tag).configure(conf)
  end

  def stub_get_logs()
    file = File.open("test/logentries/logs.json", 'rb')
    stub_request(:get, "https://rest.logentries.com/management/logs").
    with(headers: {'X-Api-Key'=>'foobar'}).
    to_return(status: 200, body: file, headers: {})
  end

  def test_happy_path
    stubs = []
    stubs << stub_logsets()
    stubs << stub_log_post("70347838-87d8-43f7-82cc-fb6f63623893")

    logs_stub = stub_get_logs()

    d1 = create_driver(CONFIG)
    time = Time.parse("2011-01-02 13:14:15 UTC").to_i

    d1.emit({"namespace": "TestLogSets", "container_name": "test1"}, time)

    stubs.map{|stub| assert_requested(stub)}
    assert_requested(logs_stub, times: 2)
  end

  def test_remove_part_of_tag
    stubs = []
    stubs << stub_logsets()
    stubs << stub_log_post("70347838-87d8-43f7-82cc-fb6f63623893")

    logs_stub = stub_get_logs()

    d1 = create_driver(CONFIG)
    time = Time.parse("2011-01-02 13:14:15 UTC").to_i

    d1.emit({"namespace": "TestLogSets", "container_name": "remove-me-test1"}, time)

    stubs.map{|stub| assert_requested(stub)}
    assert_requested(logs_stub, times: 2)
  end

  def test_create_log
    stubs = []
    stubs << stub_logsets()
    stubs << stub_log_create()
    stubs << stub_log_post("new-log-token")
    logs_stub = stub_get_logs()


    d1 = create_driver(CONFIG)
    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    d1.emit({"namespace": "TestLogSets", "container_name": "new_log"}, time)

    stubs.map{|stub| assert_requested(stub)}
    assert_requested(logs_stub, times: 1)
  end

  def test_create_log_and_logset
    stubs = []
    stubs << stub_logsets()
    stubs << stub_log_create()
    stubs << stub_logset_create("new-log-set")

    stubs << stub_log_post("new-log-token")

    logs_stub = stub_get_logs()

    d1 = create_driver(CONFIG)
    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    d1.emit({"namespace": "new-log-set", "container_name": "new_log"}, time)

    stubs.map{|stub| assert_requested(stub)}
    assert_requested(logs_stub, times: 1)
  end

end
