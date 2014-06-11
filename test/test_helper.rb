require 'rubygems'
require 'bundler/setup'
Bundler.require :default, :test
require 'fluent/test'
require 'fluent/plugin/out_heroku-runtime-metrics'
