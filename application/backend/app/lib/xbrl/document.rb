# XBRLインスタンスのfact検索プリミティブ。ここより上の層はXMLを知らない。
#
# 設計判断2点:
# - REXMLではなくNokogiriを使う。REXMLは有報の巨大TextBlock（HTML断片）で
#   entity expansionエラーを起こすため
# - remove_namespaces! は使わない。企業拡張タクソノミ要素（jpcrp030000-asr_EXXXXX-000:〜）と
#   標準要素が同名で衝突し得るため、「namespace URIがどの標準タクソノミか」で引く
module Xbrl
  class Document
    # タクソノミはバージョン年度がURIに含まれる（例 .../jppfs/2025-11-01/jppfs_cor）ため正規表現で吸収
    NS = {
      "jpdei_cor" => %r{disclosure\.edinet-fsa\.go\.jp/taxonomy/jpdei/},
      "jppfs_cor" => %r{disclosure\.edinet-fsa\.go\.jp/taxonomy/jppfs/},
      "jpigp_cor" => %r{disclosure\.edinet-fsa\.go\.jp/taxonomy/jpigp/},
      "jpcrp_cor" => %r{disclosure\.edinet-fsa\.go\.jp/taxonomy/jpcrp/}
    }.freeze

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
      @decimals = {}
      @contexts = {}
      @context_aliases = {}
      doc.root.element_children.each do |el|
        index_context(el) if el.name == "context" && el.namespace&.href == "http://www.xbrl.org/2003/instance"
        ctx = el.attribute("contextRef")&.value
        next if ctx.nil? # contextRefなし = fact以外の要素（unit定義など）
        # 名前空間URIからプレフィクスを正引き。企業拡張タクソノミ（jpcrp030000-asr_EXXXXX-000等）は
        # NSにマッチせずここで弾かれる = 標準タグのみを対象とする（意図的。拡張タグは企業ごとに
        # 意味の保証がないため、必要になったら NS に追加する形で明示的にオプトインする）
        prefix = NS.find { |_, pattern| el.namespace&.href&.match?(pattern) }&.first
        next if prefix.nil?
        # 同じ要素*同じコンテキストのfactは本表と注記で重複出現することがある。
        # 値は同一のはずだが、万一異なっても文書の先頭側（本表側）を採用する
        key = [ prefix, el.name, ctx ]
        next if @facts.key?(key)
        @facts[key] = el.text&.strip
        @decimals[key] = el.attribute("decimals")&.value
      end
    end

    # DBのbigint（8バイト整数）に収まる値域。XBRL上の異常値（極端な桁数）を
    # insert時のDBエラーにせず「開示なし」として落とすための境界
    BIGINT_RANGE = (-2**63..2**63 - 1)

    # 届出書などCurrentYearコンテキストを持たない書類だけ、DEIの実日付に対応付ける。
    # 元の辞書は変えず、形式判定・金額・公表比率・開示精度に同じ対応を適用する。
    def for_reporting_period(start_date:, end_date:)
      return self if @contexts.empty? || @contexts.keys.any? { |id| id.start_with?("CurrentYear") }
      beginning = Date.iso8601(start_date.to_s)
      ending = Date.iso8601(end_date.to_s)
      return self if beginning > ending
      entity = @contexts.dig("FilingDateInstant", :entity)
      return self if entity.nil?

      aliases = {}
      [ "", "_NonConsolidatedMember" ].each do |suffix|
        { "CurrentYearInstant" => [ ending.to_s ],
          "CurrentYearDuration" => [ beginning.to_s, ending.to_s ],
          "Prior1YearInstant" => [ (beginning - 1).to_s ] }.each do |name, period|
          candidates = @contexts.select do |id, context|
            id.match?(/\APrior\d+Year#{period.size == 1 ? 'Instant' : 'Duration'}#{suffix}\z/) &&
              context[:period] == period && context[:entity] == entity && context[:valid_dimensions]
          end
          # 日付が一致しない・候補が複数あるときは推測せず欠損にする。期首を期末で補わない。
          aliases["#{name}#{suffix}"] = candidates.one? ? candidates.keys.first : nil
        end
      end
      dup.tap { |view| view.instance_variable_set(:@context_aliases, aliases) }
    rescue Date::Error
      self
    end

    # "jppfs_cor:NetSales" 形式のqnameとコンテキストで整数値を引く。なければnil
    def money(qname, context)
      raw = text(qname, context)
      return nil if raw.nil? || raw.empty?
      # exception: false → 数値でない値（空タグ・テキスト）はnil扱い。
      # to_iを使わない理由: to_iは"abc"を0にしてしまい「開示なし」と「ゼロ」の区別が壊れる
      value = Integer(raw, exception: false)
      BIGINT_RANGE.cover?(value) ? value : nil
    end

    # 切捨て開示も含むため1表示単位未満を上限とする。割合による許容は設けない。
    def rounding_error(qname, context)
      prefix, name = qname.split(":")
      decimals = @decimals[[ prefix, name, @context_aliases.fetch(context, context) ]]
      return 0.to_d if decimals == "INF"
      places = Integer(decimals, exception: false)
      return nil unless places && (-18..18).cover?(places)
      BigDecimal("10") ** -places
    end

    def text(qname, context)
      prefix, name = qname.split(":")
      @facts[[ prefix, name, @context_aliases.fetch(context, context) ]]
    end

    private
      def index_context(element)
        id = element["id"].to_s
        return unless id == "FilingDateInstant" || id.match?(/\A(?:CurrentYear|Prior\d+Year)(?:Instant|Duration)(?:_NonConsolidatedMember)?\z/)
        ns = { "i" => "http://www.xbrl.org/2003/instance" }
        identifier = element.at_xpath("./i:entity/i:identifier", ns)
        period = element.at_xpath("./i:period", ns)
        members = element.xpath("./i:scenario/* | ./i:entity/i:segment/*", ns)
        valid_dimensions = members.empty?
        if id.end_with?("_NonConsolidatedMember")
          member = members.first
          valid_dimensions = members.one? && member.name == "explicitMember" &&
            member.namespace&.href == "http://xbrl.org/2006/xbrldi" &&
            standard_member?(member, member["dimension"], "ConsolidatedOrNonConsolidatedAxis") &&
            standard_member?(member, member.text.strip, "NonConsolidatedMember")
        end
        @contexts[id] = {
          entity: identifier && [ identifier["scheme"], identifier.text.strip ],
          period: period&.element_children&.map { |node| node.text.strip },
          valid_dimensions: valid_dimensions
        }
      end

      def standard_member?(element, qname, expected)
        prefix, name = qname.to_s.split(":")
        uri = element.namespaces["xmlns:#{prefix}"]
        name == expected && uri && %w[jppfs_cor jpcrp_cor jpigp_cor].any? { |key| uri.match?(NS.fetch(key)) }
      end
  end
end
