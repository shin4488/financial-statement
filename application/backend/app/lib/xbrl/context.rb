module Xbrl
  # IDの命名によらず、企業・実日付・連結区分をXMLから読む。
  # 財務諸表全体に使えない部門別・予測・typedMember等の文脈は選択対象にしない。
  class Context
    INSTANCE_NS = "http://www.xbrl.org/2003/instance".freeze
    XML_NS = { "i" => INSTANCE_NS }.freeze
    DIMENSION_NS = "http://xbrl.org/2006/xbrldi".freeze

    attr_reader :entity, :period, :consolidation

    def initialize(element)
      identifier = element.at_xpath("./i:entity/i:identifier", XML_NS)
      if identifier && identifier["scheme"].present? && identifier.text.strip.present?
        @entity = [ identifier["scheme"], identifier.text.strip ].freeze
      end
      @period = read_period(element.at_xpath("./i:period", XML_NS))
      @consolidation = read_consolidation(element)
    end

    # EDINETの期間は日付形式。未対応の日時・不正な日付を切り詰めて採用しない。
    def self.date(value)
      text = value.to_s
      Date.iso8601(text) if text.match?(/\A\d{4}-\d{2}-\d{2}\z/)
    rescue Date::Error
      nil
    end

    private
      def read_period(element)
        return unless element
        nodes = element.element_children
        return unless nodes.all? { |node| node.namespace&.href == INSTANCE_NS }
        dates = nodes.map { |node| self.class.date(node.text.strip) }
        return if dates.any?(&:nil?)
        case nodes.map(&:name)
        when [ "instant" ] then dates.freeze
        when [ "startDate", "endDate" ] then dates.freeze if dates.first <= dates.last
        end
      end

      def read_consolidation(element)
        containers = element.xpath("./i:scenario | ./i:entity/i:segment", XML_NS)
        return if containers.any? { |node| node.children.any? { |child| child.text? && child.text.strip.present? } }
        members = containers.flat_map { |node| node.element_children.to_a }
        return :consolidated if members.empty?
        return unless members.one?
        member = members.first
        return unless member.name == "explicitMember" && member.namespace&.href == DIMENSION_NS
        return unless standard_member?(member, member["dimension"], "ConsolidatedOrNonConsolidatedAxis")
        return :non_consolidated if standard_member?(member, member.text.strip, "NonConsolidatedMember")
        :consolidated if standard_member?(member, member.text.strip, "ConsolidatedMember")
      end

      def standard_member?(element, qname, expected)
        prefix, name = qname.to_s.split(":")
        uri = element.namespaces["xmlns:#{prefix}"]
        name == expected && uri&.match?(%r{\Ahttps?://disclosure\.edinet-fsa\.go\.jp/taxonomy/(jppfs|jpcrp|jpigp)/[^/]+/\1_cor\z})
      end
  end
end
