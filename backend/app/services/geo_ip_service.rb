# frozen_string_literal: true

# IP アドレスから地域情報を推定するサービス
#
# 現在はプライベート IP の判定と基本的な分類のみ実装。
# 将来的に MaxMind GeoLite2 等の GeoIP データベースを導入する場合は
# このサービスを拡張する。
#
# 使用例:
#   GeoIpService.lookup("203.0.113.1")  # => "unknown"
#   GeoIpService.lookup("192.168.1.1")  # => "private"
#   GeoIpService.lookup("127.0.0.1")    # => "loopback"
#   GeoIpService.lookup(nil)            # => nil
class GeoIpService
  # プライベート IP アドレスの範囲（RFC 1918 + IPv6 ULA + リンクローカル）
  PRIVATE_RANGES = [
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("fc00::/7"),      # IPv6 ユニークローカルアドレス（ULA）
    IPAddr.new("fe80::/10"),     # IPv6 リンクローカルアドレス
    IPAddr.new("169.254.0.0/16") # IPv4 リンクローカルアドレス（APIPA）
  ].freeze

  LOOPBACK_RANGES = [
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("::1/128")
  ].freeze

  class << self
    # IP アドレスから地域情報を推定する
    #
    # @param ip_address [String, nil] IP アドレス文字列
    # @return [String, nil] 地域情報（"private", "loopback", "unknown"）、nil の場合は nil
    def lookup(ip_address)
      return nil if ip_address.blank?

      ip = parse_ip(ip_address)
      return nil unless ip

      return "loopback" if loopback?(ip)
      return "private" if private_ip?(ip)

      # TODO: MaxMind GeoLite2 等の GeoIP データベースを導入して
      #       実際の地域情報（国・都道府県）を返すようにする
      "unknown"
    end

    private

    # IP アドレス文字列をパースする
    # IPv6 のゾーン ID（%eth0 等）は除去してからパースする
    #
    # @param ip_address [String] IP アドレス文字列
    # @return [IPAddr, nil] パース結果、不正な場合は nil
    def parse_ip(ip_address)
      # IPv6 リンクローカルアドレスのゾーン ID を除去（例: "fe80::1%eth0" → "fe80::1"）
      cleaned = ip_address.to_s.split("%").first
      IPAddr.new(cleaned)
    rescue IPAddr::InvalidAddressError
      nil
    end

    # ループバックアドレスかどうかを判定する
    def loopback?(ip)
      LOOPBACK_RANGES.any? { |range| range.include?(ip) }
    end

    # プライベート IP アドレスかどうかを判定する
    def private_ip?(ip)
      PRIVATE_RANGES.any? { |range| range.include?(ip) }
    end
  end
end
