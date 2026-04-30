ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Gemfile に記載された gem をセットアップ
require "bootsnap/setup" # 起動高速化
