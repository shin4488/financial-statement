module Disclosure
  # 証券コードの桁変換。EDINET（DB保存値）は5桁「4桁コード + 末尾0」、UIは4桁で扱う。
  # 変換は往復で対になるため、片方だけ直して食い違わないよう1箇所に集める
  module StockCode
    module_function

    def to_edinet(display_code) = "#{display_code}0"

    def to_display(edinet_code) = edinet_code&.delete_suffix("0")
  end
end
