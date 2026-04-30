# このファイルは Rack ベースのサーバーがアプリケーションを起動するために使用する
require_relative "config/environment"

run Rails.application
Rails.application.load_server
