# frozen_string_literal: true

# 統一エラーハンドリング
# 全 API エラーを統一 JSON 形式（{ error: { code, message, details } }）で返す
#
# ApplicationController に include することで、
# 未処理の例外を自動的にキャッチし、適切な HTTP ステータスコードと
# 統一されたエラーレスポンスを返す。
#
# 設計ドキュメント セクション 7 に準拠
module ErrorHandler
  extend ActiveSupport::Concern

  included do
    # 順序が重要: 下に書いたものが先にマッチする

    # 500: 予期しないエラー（最も広いキャッチ）
    rescue_from StandardError, with: :handle_internal_error

    # 404: ルーティングエラー
    rescue_from ActionController::RoutingError, with: :handle_not_found

    # 400: パラメータ不足
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

    # 422: ActiveRecord バリデーションエラー
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid

    # 404: ActiveRecord レコード未検出
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found

    # 409: ActiveRecord 一意制約違反
    rescue_from ActiveRecord::RecordNotUnique, with: :handle_record_not_unique

    # 502: 外部サービスエラー（Google API）
    rescue_from GoogleOauthService::Error, with: :handle_external_service_error
    rescue_from FreebusySyncService::Error, with: :handle_external_service_error

    # 502: ネットワークエラー
    rescue_from Net::OpenTimeout, with: :handle_network_timeout
    rescue_from Net::ReadTimeout, with: :handle_network_timeout
    rescue_from Errno::ECONNREFUSED, with: :handle_connection_refused
    rescue_from SocketError, with: :handle_connection_refused
  end

  private

  # 500: 予期しないサーバーエラー
  def handle_internal_error(exception)
    log_error(exception)

    render json: {
      error: {
        code: "INTERNAL_SERVER_ERROR",
        message: "サーバー内部エラーが発生しました。しばらく待ってから再試行してください。"
      }
    }, status: :internal_server_error
  end

  # 400: パラメータ不足
  def handle_parameter_missing(exception)
    render json: {
      error: {
        code: "PARAMETER_MISSING",
        message: "必須パラメータが不足しています。",
        details: [{ field: exception.param.to_s, message: "#{exception.param} は必須です。" }]
      }
    }, status: :bad_request
  end

  # 422: バリデーションエラー
  def handle_record_invalid(exception)
    record = exception.record
    render json: {
      error: {
        code: "VALIDATION_ERROR",
        message: "入力内容に問題があります。",
        details: record.errors.map { |e| { field: e.attribute.to_s, message: e.message } }
      }
    }, status: :unprocessable_entity
  end

  # 404: レコード未検出
  def handle_record_not_found(_exception)
    render json: {
      error: {
        code: "NOT_FOUND",
        message: "リソースが見つかりません。"
      }
    }, status: :not_found
  end

  # 404: ルーティングエラー
  def handle_not_found(_exception)
    render json: {
      error: {
        code: "NOT_FOUND",
        message: "リクエストされたURLが見つかりません。"
      }
    }, status: :not_found
  end

  # 409: 一意制約違反
  def handle_record_not_unique(_exception)
    render json: {
      error: {
        code: "CONFLICT",
        message: "データが競合しています。既に同じデータが存在します。"
      }
    }, status: :conflict
  end

  # 502: 外部サービスエラー（Google API、Discord API 等）
  def handle_external_service_error(exception)
    log_error(exception)

    render json: {
      error: {
        code: "EXTERNAL_SERVICE_ERROR",
        message: "外部サービスとの通信に失敗しました。しばらく待ってから再試行してください。"
      }
    }, status: :bad_gateway
  end

  # 502: ネットワークタイムアウト
  def handle_network_timeout(exception)
    log_error(exception)

    render json: {
      error: {
        code: "EXTERNAL_SERVICE_TIMEOUT",
        message: "外部サービスへの接続がタイムアウトしました。しばらく待ってから再試行してください。"
      }
    }, status: :bad_gateway
  end

  # 502: 接続拒否
  def handle_connection_refused(exception)
    log_error(exception)

    render json: {
      error: {
        code: "EXTERNAL_SERVICE_UNAVAILABLE",
        message: "外部サービスに接続できません。しばらく待ってから再試行してください。"
      }
    }, status: :bad_gateway
  end

  # エラーログ出力
  # 本番環境では詳細なスタックトレースを記録する
  def log_error(exception)
    Rails.logger.error(
      "[#{exception.class}] #{exception.message}\n" \
      "#{exception.backtrace&.first(10)&.join("\n")}"
    )
  end
end
