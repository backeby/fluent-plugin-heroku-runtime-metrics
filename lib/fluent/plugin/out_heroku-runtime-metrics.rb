# <match **>
#   type heroku-runtime-metrics
# </match>
class Fluent::HerokuRuntimeMetricsOutput < Fluent::Output
  Fluent::Plugin.register_output('heroku-runtime-metrics', self)

  config_param :key, :string, default: 'message'
  config_param :prefix, :string, default: 'hrm_'

  def configure(conf)
    super

    @mapping = Hash[VALID_KEYS.map { |e| [e, "#{@prefix}#{e}"] }]

    config_keys = VALID_KEYS.map { |e| e.sub('sample#', '') }
    config_map = Hash[config_keys.zip VALID_KEYS]

    conf.elements.select { |element| element.name == 'record' }.each do |element|
      element.each do |key, value|
        unless config_keys.include? key
          raise Fluent::ConfigError, "invalid config key. #{key}"
        end
        @mapping[config_map[key]] = value
      end
    end
  end

  def emit(tag, es, chain)
    chain.next
    es.each { |time, record| Fluent::Engine.emit tag, time, parse(record) }
  end

  LOADAVG_KEYS = %w(sample#load_avg_1m sample#load_avg_5m sample#load_avg_15m)
  MEMORY_KEYS  = %w(sample#memory_total sample#memory_rss sample#memory_cache sample#memory_swap)
  PAGE_KEYS    = %w(sample#memory_pgpgin sample#memory_pgpgout)
  VALID_KEYS   = %w(source dyno) + LOADAVG_KEYS + MEMORY_KEYS + PAGE_KEYS

  def parse(record)
    return record unless record[@key]
    message = record[@key]
    return record unless detect message
    metrics = extract message
    return record if metrics.empty?
    merge record, metrics
  end

  def detect(message)
    return false if message !~ /source=/
    return false if message !~ /dyno=/
    return false if message !~ /sample#(?:(?:load_avg_(?:1|5|15)m)|(?:memory_(?:total|rss|cache|swap|pgpgin|pgpgout)))=/
    true
  end

  def extract(message)
    Hash[message.split(' ').map { |e| e.split('=') }.select { |k, _| VALID_KEYS.include? k }].tap do |hash|
      LOADAVG_KEYS.each do |key|
        hash[key] = treatment_loadaverage hash[key] if hash.key? key
      end

      MEMORY_KEYS.each do |key|
        hash[key] = treatment_mb hash[key] if hash.key? key
      end

      PAGE_KEYS.each do |key|
        hash[key] = treatment_pages hash[key] if hash.key? key
      end
    end
  end

  def merge(record, metrics)
    @mapping.each do |key, value|
      next unless metrics.key? key
      record[value] = metrics[key]
    end
    record
  end

  def treatment_loadaverage(value)
    value.to_f
  end

  def treatment_mb(value)
    (value.sub('MB', '').to_f * 1024 * 1024).round
  end

  def treatment_pages(value)
    value.sub('pages', '').to_i
  end
end
