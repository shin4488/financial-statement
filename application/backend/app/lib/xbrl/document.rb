# XBRLインスタンスのfact検索プリミティブ。ここより上の層はXMLを知らない。
#
# 設計判断2点:
# - REXMLではなくNokogiriを使う。REXMLは有報の巨大TextBlock（HTML断片）で
#   entity expansionエラーを起こすため
# - remove_namespaces! は使わない。企業拡張タクソノミ要素（jpcrp030000-asr_EXXXXX-000:〜）と
#   標準要素が同名で衝突し得るため、「namespace URIがどの標準タクソノミか」で引く
module Xbrl
  class Document
    NS = {
      "jpdei_cor" => %r{disclosure\.edinet-fsa\.go\.jp/taxonomy/jpdei/},
      "jppfs_cor" => %r{disclosure\.edinet-fsa\.go\.jp/taxonomy/jppfs/},
      "jpigp_cor" => %r{disclosure\.edinet-fsa\.go\.jp/taxonomy/jpigp/},
      "jpcrp_cor" => %r{disclosure\.edinet-fsa\.go\.jp/taxonomy/jpcrp/}
    }.freeze
    # タクソノミはバージョン年度がURIに含まれる（例 .../jppfs/2025-11-01/jppfs_cor）ため正規表現で吸収

    def self.load(path)
      # cfg.huge: 有報XBRLは数MB・数万要素になるためNokogiriのデフォルト制限を外す
      doc = File.open(path) { |f| Nokogiri::XML(f) { |cfg| cfg.huge } }
      new(doc)
    end

    def initialize(doc)
      # {["jppfs_cor", "NetSales", "CurrentYearDuration"] => "12345", ...} を1passで構築。
      # 科目ごとにXPath検索する方式だと科目数*全要素走査になるため、
      # 先に全factをハッシュ化して以降の検索をO(1)にする
      @facts = {}
      doc.root.element_children.each do |el|
        ctx = el.attribute("contextRef")&.value
        next if ctx.nil? # contextRefなし = fact以外の要素（unit定義など）
        # 名前空間URIからプレフィクスを正引き。企業拡張タクソノミ（jpcrp030000-asr_EXXXXX-000等）は
        # NSにマッチせずここで弾かれる = 標準タグのみを対象とする（意図的。拡張タグは企業ごとに
        # 意味の保証がないため、必要になったら NS に追加する形で明示的にオプトインする）
        prefix = NS.find { |_, pattern| el.namespace&.href&.match?(pattern) }&.first
        next if prefix.nil?
        # ||= : 同じ要素*同じコンテキストのfactは本表と注記で重複出現することがある。
        # 値は同一のはずだが、万一異なっても文書の先頭側（本表側）を採用する
        @facts[[ prefix, el.name, ctx ]] ||= el.text&.strip
      end
    end

    # DBのbigint（8バイト整数）に収まる値域。XBRL上の異常値（極端な桁数）を
    # insert時のDBエラーにせず「開示なし」として落とすための境界
    BIGINT_RANGE = (-2**63..2**63 - 1)

    # "jppfs_cor:NetSales" 形式のqnameとコンテキストで整数値を引く。なければnil
    def money(qname, context)
      prefix, name = qname.split(":")
      raw = @facts[[ prefix, name, context ]]
      return nil if raw.nil? || raw.empty?
      # exception: false → 数値でない値（空タグ・テキスト）はnil扱い。
      # to_iを使わない理由: to_iは"abc"を0にしてしまい「開示なし」と「ゼロ」の区別が壊れる
      value = Integer(raw, exception: false)
      BIGINT_RANGE.cover?(value) ? value : nil
    end

    # フォールバックリスト: 最初に値が取れたものを返す（リストの並び順=優先度）
    def money_first(qnames, context)
      qnames.lazy.filter_map { |q| money(q, context) }.first
    end

    def text(qname, context)
      prefix, name = qname.split(":")
      @facts[[ prefix, name, context ]]
    end
  end
end
