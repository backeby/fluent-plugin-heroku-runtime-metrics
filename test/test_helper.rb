require 'rubygems'
require 'bundler/setup'
Bundler.require :default, :test
require 'fluent/test'
require 'fluent/plugin/out_heroku-runtime-metrics'

module Test
  module Unit
    module Assertions
      def assert_record(expected, actual)
        expected.each do |key, val|
          assert actual.key? key
          assert_equal val, actual[key]
        end
      end
    end
  end
end
