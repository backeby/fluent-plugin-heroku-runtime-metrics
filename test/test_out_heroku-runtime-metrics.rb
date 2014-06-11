require 'test_helper'
require 'pp'

class Fluent::HerokuRuntimeMetricsOutputTest < Test::Unit::TestCase
  def test_config_1
    driver = create_driver <<EOF
key data
EOF
    assert_equal 'data', driver.instance.config['key']
  end

  def test_config_2
    create_driver <<EOF
<record>
  dyno heroku_dyno
</record>
EOF
  end

  def test_config_3
    assert_raise Fluent::ConfigError do
      create_driver <<EOF
<record>
  dyon heroku_dyno
</record>
EOF
    end
  end

  def test_config_4
    driver = create_driver <<EOF
prefix heroku_
EOF
    assert_equal 'heroku_', driver.instance.config['prefix']
  end

  def test_emit_1
    driver = create_driver
    driver.run { driver.emit('message' => 'source=web.1 dyno=heroku.appid.uuid sample#memory_total=512MB') }
    tag, time, record = driver.emits.first

    assert record.key? 'hrm_source'
    assert record.key? 'hrm_dyno'
    assert record.key? 'hrm_sample#memory_total'
  end

  def test_emit_2
    driver = create_driver
    driver.run { driver.emit('message' => 'source=web.1 dyno=heroku.appid.uuid sample.memory_total=512MB') }
    tag, time, record = driver.emits.first

    refute record.key? 'hrm_source'
    refute record.key? 'hrm_dyno'
    refute record.key? 'hrm_sample#memory_total'
  end

  def test_emit_3
    driver = create_driver
    driver.run { driver.emit('message' => 'source=web.1 dyno=heroku.appid.uuid sample#memory_total=512MB') }
    tag, time, record = driver.emits.first

    assert_equal 'web.1', record['hrm_source']
    assert_equal 'heroku.appid.uuid', record['hrm_dyno']
    assert_equal 512 * 1024 * 1024, record['hrm_sample#memory_total']
  end

  def test_emit_4
    driver = create_driver
    driver.run { driver.emit('message' => 'source=web.1 dyno=heroku.appid.uuid sample#memory_pgpgin=1129pages') }
    tag, time, record = driver.emits.first

    assert_equal 1129, record['hrm_sample#memory_pgpgin']
  end

  def test_emit_5
    driver = create_driver
    driver.run { driver.emit('message' => 'source=web.1 dyno=heroku.appid.uuid sample#load_avg_1m=0.00') }
    tag, time, record = driver.emits.first

    assert_equal 0.0, record['hrm_sample#load_avg_1m']
  end

  def test_emit_6
    driver = create_driver
    driver.run { driver.emit('message' => 'source=web.1 dyno=heroku.appid.uuid sample#load_avg_1m=123.456') }
    tag, time, record = driver.emits.first

    assert_equal 123.456, record['hrm_sample#load_avg_1m']
  end

  def test_config_emit_1
    driver = create_driver <<EOF
key log
prefix heroku-runtime-metrics_
<record>
  memory_cache mc
</record>
EOF
    driver.run { driver.emit('log' => 'source=web.1 dyno=heroku.appid.uuid sample#memory_cache=0.5MB sample#memory_rss=1.93MB') }
    tag, time, record = driver.emits.first

    assert_equal 'web.1', record['heroku-runtime-metrics_source']
    assert_equal 'heroku.appid.uuid', record['heroku-runtime-metrics_dyno']
    assert_equal (0.5 * 1024 * 1024).round, record['mc']
    assert_equal (1.93 * 1024 * 1024).round, record['heroku-runtime-metrics_sample#memory_rss']
  end

  def test_config_emit_2
    driver = create_driver <<EOF
key long
prefix
<record>
  memory_cache mc
</record>
EOF
    driver.run { driver.emit('long' => 'source=web.1 dyno=heroku.appid.uuid sample#memory_cache=0.5MB sample#memory_pgpgin=1.93pages') }
    tag, time, record = driver.emits.first

    assert_equal 'web.1', record['source']
    assert_equal 'heroku.appid.uuid', record['dyno']
    assert_equal (0.5 * 1024 * 1024).round, record['mc']
    assert_equal (1.93).to_i, record['sample#memory_pgpgin']
  end

  def setup
    Fluent::Test.setup
  end

  def create_driver(config="")
    Fluent::Test::OutputTestDriver.new(Fluent::HerokuRuntimeMetricsOutput).configure(config)
  end
end
