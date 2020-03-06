require 'rubygems'
require 'bundler'

Bundler.require

require 'dotenv/load'
require './clubbase'
run Sinatra::Application
