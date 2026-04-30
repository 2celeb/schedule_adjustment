# アプリケーション全体の基底モデル
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
