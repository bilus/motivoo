require 'sinatra'
require 'haml'
require File.join(File.dirname(__FILE__), 'app')

run Sinatra::Application