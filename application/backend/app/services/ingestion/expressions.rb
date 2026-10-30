module Ingestion
  # 取得式。対応表の値を評価して、科目の金額を求める。単一タグ（Tag）を葉とし、ほかの取得式を子に持つ式（Fallback・Sum・Max）も
  # 同じメソッドを持つため、記法を足すときは同じメソッドを持つクラスを1つ足せば、ほかの式の中にも置ける。
  # 取得式どうしに共有する実装はないため、基底クラスを作らず、次のメソッドを揃える。
  #   evaluate(source, period:, consolidation:) … 金額と端数の上限の組（Measured）。取れなければ nil
  #   amount(source, period:, consolidation:)   … 金額だけ。端数の上限を求めないため、金額にしか答えないXBRLでも単一タグを評価できる（形式判定）
  #   blank?(source, period:, consolidation:)   … 金額が取れず、行はあるが値が空（表では「－」。XBRLでは値のないタグ）か
  # source は Xbrl::ReportingPeriod か、標準のコンテキストIDで答える文書（Xbrl::Document やspecの代役）。
  # 取得式が呼ぶのは money・rounding_error・text・element_names だけにする（代役はspecごとにこの一部にしか答えない）。
  # period は :instant・:duration・:prior_instant、consolidation は :consolidated・:non_consolidated
  module Expressions
    # 対応表の値を取得式に揃える。単一タグは裸の文字列で、フォールバック（先に取れた候補を採る）は配列で書ける
    def self.wrap(spec)
      case spec
      when String then Tag.new(spec)
      when Array then Fallback.new(spec.map { |entry| wrap(entry) })
      else spec
      end
    end

    # 対応表の記法。意味は各クラスにある
    def self.sum(*qnames, distinct_amounts: false, all_present: false) = Sum.new(qnames.map { |qname| Tag.new(qname) }, distinct_amounts, all_present)
    def self.max(*entries) = Max.new(entries.map { |entry| wrap(entry) })
    def self.filer_ext(pattern) = FilerExtension.new(pattern)
    def self.ratio(qname) = Ratio.new(qname)

    # 取得候補の一覧。フォールバックはその要素を先頭から、ほかの取得式はそれ自身を1つの候補とする
    def self.candidates(expression) = expression.is_a?(Fallback) ? expression.entries : [ expression ]

    # 取得候補のうち、財務諸表の本表のもの。経営指標の要約の単一タグを除く（sum・max の中のタグは除かない）
    def self.statement_candidates(expression) = candidates(expression).reject { |entry| entry.is_a?(Tag) && entry.summary? }
    private_class_method :candidates
  end
end
