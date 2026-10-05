# XBRLインスタンスのfact検索プリミティブ。ここより上の層はXMLを知らない。
#
# 設計判断2点:
# - REXMLではなくNokogiriを使う。REXMLは有報の巨大TextBlock（HTML断片）で
#   entity expansionエラーを起こすため
# - remove_namespaces! は使わない。企業拡張タクソノミ要素（jpcrp030000-asr_EXXXXX-000:〜）と
#   標準要素が同名で衝突し得るため、「namespace URIが標準タクソノミか企業拡張か」で接頭辞を分けて引く
module Xbrl
  class Document
    # タクソノミはバージョン年度がURIに含まれる（例 .../jppfs/2025-11-01/jppfs_cor）ため正規表現で吸収
    NS = {
      "jpdei_cor" => %r{disclosure\.edinet-fsa\.go\.jp/taxonomy/jpdei/},
      "jppfs_cor" => %r{disclosure\.edinet-fsa\.go\.jp/taxonomy/jppfs/},
      "jpigp_cor" => %r{disclosure\.edinet-fsa\.go\.jp/taxonomy/jpigp/},
      "jpcrp_cor" => %r{disclosure\.edinet-fsa\.go\.jp/taxonomy/jpcrp/},
      # 提出者が定義した企業拡張タグ。1つの書類に入っているのは提出者1社分なので、会社が違っても名前はぶつからない。
      # 様式コード（有報のjpcrp030000、届出書のjpcrp040000など）の名前空間に合わせ、
      # 標準タクソノミ（.../taxonomy/jpcrp/...）には当てない
      "filer_ext" => %r{disclosure\.edinet-fsa\.go\.jp/jpcrp\d{6}/}
    }.freeze

    def self.load(path)
      # cfg.huge: 有報XBRLは数MB・数万要素になるためNokogiriのデフォルト制限を外す
      doc = File.open(path) { |f| Nokogiri::XML(f) { |cfg| cfg.huge } }
      new(doc)
    end

    def initialize(doc)
      # {["jppfs_cor", "NetSales", "CurrentYearDuration"] => Fact, ...} を1passで構築。
      # 科目ごとにXPath検索する方式だと科目数*全要素走査になるため、
      # 先に全factをハッシュ化して以降の検索をO(1)にする
      @facts = {}
      @contexts = {}
      @element_names = {}
      units = doc.root.element_children.select { |el| el.name == "unit" && el.namespace&.href == Context::INSTANCE_NS }
                 .to_h { |el| [ el["id"], unit_measure(el) ] }
      doc.root.element_children.each do |el|
        if el.name == "context" && el.namespace&.href == Context::INSTANCE_NS
          @contexts[el["id"]] = Context.new(el)
        end
        ctx = el.attribute("contextRef")&.value
        next if ctx.nil? # contextRefなし = fact以外の要素（unit定義など）
        # 名前空間URIからプレフィクスを正引きし、NSにない名前空間の要素は読まない。
        # 企業拡張タグは企業ごとに意味の保証がないため、読み込んでも検索は「接頭辞:要素名」の指定だけで行い、
        # 使うのはマッピング表に書いた要素に限る
        prefix = NS.find { |_, pattern| el.namespace&.href&.match?(pattern) }&.first
        next if prefix.nil?
        (@element_names[prefix] ||= Set.new) << el.name
        # 同じ要素*同じコンテキストのfactは本表と注記で重複出現することがある。
        # 値は同一のはずだが、万一異なっても文書の先頭側（本表側）を採用する
        key = [ prefix, el.name, ctx ]
        fact = Fact.new(value: el.text&.strip, decimals: el["decimals"], unit: units[el["unitRef"]] || el["unitRef"])
        # 円表示の金額には開示された円換算値を使う。外貨が先に現れても円を優先する。
        next if @facts.key?(key) && !(fact.unit == Fact::JPY && @facts[key].unit != Fact::JPY)
        @facts[key] = fact
      end
    end

    # XML上のIDによる検索と、事業年度を指定した検索を分ける。
    def for_reporting_period(start_date:, end_date:)
      ReportingPeriod.new(self, contexts: @contexts, start_date: start_date, end_date: end_date)
    end

    def fact(qname, context)
      prefix, name = qname.split(":")
      @facts[[ prefix, name, context ]]
    end

    # 企業拡張タグは会社ごとに要素名が違うため、名前の形で探すときに一覧を使う
    def element_names(prefix) = @element_names.fetch(prefix, Set.new)

    def money(qname, context) = fact(qname, context)&.money
    def text(qname, context) = fact(qname, context)&.value
    def rounding_error(qname, context) = fact(qname, context)&.rounding_error

    private
      def unit_measure(element)
        measure = element.at_xpath("./i:measure", Context::XML_NS)
        return unless measure && element.element_children.one?
        prefix, name = measure.text.strip.split(":")
        uri = measure.namespaces["xmlns:#{prefix}"]
        "{#{uri}}#{name}" if uri && name
      end
  end
end
