module Types
  # GraphQL::Types::BigInt を使わない理由:
  # あちらは文字列でシリアライズされるため、全クライアント（Webフロント・ブラウザ拡張）に
  # 数値変換の実装が必要になる。日本企業の金額の最大値（総資産400兆円台 = 4e14）は
  # JSの安全整数域（Number.MAX_SAFE_INTEGER = 9e15）に収まるため、数値のまま返す方が契約として単純
  class MoneyType < Types::BaseScalar
    graphql_name "Money"
    description "円単位の金額。Int32の範囲を超え得るがJSON上は数値のまま返す"

    def self.coerce_input(value, _ctx)
      value.nil? ? nil : Integer(value)
    end

    def self.coerce_result(value, _ctx)
      value.to_i
    end
  end
end
