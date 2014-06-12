require 'test_helper'

class Fluent::HerokuRuntimeMetricsOutputTest < Test::Unit::TestCase
  def test_config_1
    driver = create_driver <<-EOF
      key data
    EOF
    assert_equal 'data', driver.instance.config['key']
  end

  def test_config_2
    assert_nothing_raised Fluent::ConfigError do
      create_driver <<-EOF
        <record>
          dyno heroku_dyno
        </record>
      EOF
    end
  end

  def test_config_3
    assert_raise Fluent::ConfigError do
      create_driver <<-EOF
        <record>
          dyon heroku_dyno
        </record>
      EOF
    end
  end

  def test_config_4
    driver = create_driver <<-EOF
      prefix heroku_
    EOF
    assert_equal 'heroku_', driver.instance.config['prefix']
  end

  def test_emit_1
    driver = create_driver
    driver.emit('message' => 'source=web.1 dyno=heroku.appid.uuid sample#memory_total=512MB')
    driver.run
    tag, time, record = driver.emits.first

    assert record.key? 'hrm_source'
    assert record.key? 'hrm_dyno'
    assert record.key? 'hrm_sample#memory_total'
  end

  # sample.memory_total is invalid format
  def test_emit_2
    driver = create_driver
    driver.emit('message' => 'source=web.1 dyno=heroku.appid.uuid sample.memory_total=512MB')
    driver.run
    tag, time, record = driver.emits.first

    refute record.key? 'hrm_source'
    refute record.key? 'hrm_dyno'
    refute record.key? 'hrm_sample#memory_total'
  end

  def test_emit_3
    driver = create_driver
    driver.emit('message' => 'source=web.1 dyno=heroku.appid.uuid sample#memory_total=512MB')
    driver.run
    tag, time, record = driver.emits.first

    assert_record({
                   'hrm_source'              => 'web.1',
                   'hrm_dyno'                => 'heroku.appid.uuid',
                   'hrm_sample#memory_total' => (512 * 1024 * 1024),
                 }, record)
  end

  def test_emit_4
    driver = create_driver
    driver.emit('message' => 'source=web.1 dyno=heroku.appid.uuid sample#memory_pgpgin=1129pages')
    driver.run
    tag, time, record = driver.emits.first

    assert_record({ 'hrm_sample#memory_pgpgin' => 1129 }, record)
  end

  def test_emit_5
    driver = create_driver
    driver.emit('message' => 'source=web.1 dyno=heroku.appid.uuid sample#load_avg_1m=0.00')
    driver.run
    tag, time, record = driver.emits.first

    assert_record({ 'hrm_sample#load_avg_1m' => 0.0 }, record)
  end

  def test_emit_6
    driver = create_driver
    driver.emit('message' => 'source=web.1 dyno=heroku.appid.uuid sample#load_avg_1m=123.456')
    driver.run
    tag, time, record = driver.emits.first

    assert_record({ 'hrm_sample#load_avg_1m' => 123.456 }, record)
  end

  def test_config_emit_1
    driver = create_driver <<-EOF
      key log
      prefix heroku-runtime-metrics_
      <record>
        memory_cache mc
      </record>
    EOF
    driver.emit('log' => 'source=web.1 dyno=heroku.appid.uuid sample#memory_cache=0.5MB sample#memory_rss=1.93MB')
    driver.run
    tag, time, record = driver.emits.first

    assert_record({
                    'heroku-runtime-metrics_source'            => 'web.1',
                    'heroku-runtime-metrics_dyno'              => 'heroku.appid.uuid',
                    'mc'                                       => (0.5 * 1024 * 1024).round,
                    'heroku-runtime-metrics_sample#memory_rss' => (1.93 * 1024 * 1024).round,
                  }, record)
  end

  def test_config_emit_2
    driver = create_driver <<-EOF
      key long
      prefix
      <record>
        memory_cache mc
      </record>
    EOF
    driver.emit('long' => 'source=web.1 dyno=heroku.appid.uuid sample#memory_cache=0.5MB sample#memory_pgpgin=1.93pages')
    driver.run
    tag, time, record = driver.emits.first

    assert_record({
                    'source'               => 'web.1',
                    'dyno'                 => 'heroku.appid.uuid',
                    'mc'                   => (0.5 * 1024 * 1024).round,
                    'sample#memory_pgpgin' => 1.93.to_i,
                  }, record)
  end

  def test_config_emit_3
    driver = create_driver <<-EOF, 'input.tagtag'
      key log
      remove_tag_prefix input.
      add_tag_suffix .appended
    EOF
    driver.emit('log' => 'source=web.1 dyno=heroku.appid.uuid sample#memory_cache=0.5MB sample#memory_pgpgin=1.93pages')
    driver.run
    tag, time, record = driver.emits.first

    assert_equal 'tagtag.appended',         tag
    assert_record({
                    'hrm_source'               => 'web.1',
                    'hrm_dyno'                 => 'heroku.appid.uuid',
                    'hrm_sample#memory_cache'  => (0.5 * 1024 * 1024).round,
                    'hrm_sample#memory_pgpgin' => 1.93.to_i,
                  }, record)
  end

  def setup
    Fluent::Test.setup
  end

  def create_driver(config='', tag='test')
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::HerokuRuntimeMetricsOutput, tag).configure(config)
  end
end
