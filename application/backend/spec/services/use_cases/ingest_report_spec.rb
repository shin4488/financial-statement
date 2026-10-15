require "rails_helper"

RSpec.describe UseCases::IngestReport do
  # Sentryへ送った通知と、送った時点の財務諸表の数・開いているトランザクションの数
  let(:notices) { [] }

  before do
    allow(Sentry).to receive(:capture_message) do |*args, **kwargs|
      notices << [ args, kwargs, Disclosure::FinancialStatement.count, ActiveRecord::Base.connection.open_transactions ]
    end
  end

  def call(xml, doc_id: "S0000001", expected_sec_code: nil)
    Dir.mktmpdir do |work_dir|
      described_class.new(client: FakeEdinetClient.new(doc_id => xml))
                     .call(doc_id: doc_id, work_dir: work_dir, expected_sec_code: expected_sec_code)
    end
  end

  it "主の財務諸表の点検の通知を、その区分を保存した直後に、1有報のトランザクションの中で送る。主でない区分は点検しない" do
    open_transactions = ActiveRecord::Base.connection.open_transactions

    call(synthetic_xbrl_xml(dei: { has_consolidated: "true" },
                            facts: { [ "jppfs_cor:NetSales", "CurrentYearDuration" ] => 300,
                                     [ "jppfs_cor:NetSales", "CurrentYearDuration_NonConsolidatedMember" ] => 100 }))

    expect(notices).to eq [ [ [ "primary statement missing bs.assets: S0000001 (jgaap_general)" ],
                              { level: :warning, fingerprint: [ "primary statement missing bs.assets" ] },
                              1, open_transactions + 1 ] ]
  end

  it "当期の科目がなく既存を残した区分は、その区分の番に、残したことを通知する" do
    call(synthetic_xbrl_xml(facts: { [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 100 }))

    call(synthetic_xbrl_xml(facts: {}), doc_id: "S0000009")

    expect(notices.map(&:first)).to eq [ [ "skip empty extraction for existing statement: S0000009 (non_consolidated)" ] ]
  end

  it "対象確認で止める書類は、判定の通知を送り、DBに書かない" do
    call(synthetic_xbrl_xml, expected_sec_code: "72030")

    aggregate_failures do
      expect(notices).to eq [ [ [ "sec code mismatch: S0000001 (list=72030 dei=45020)" ],
                                { level: :error, fingerprint: [ "sec code mismatch" ] }, 0,
                                ActiveRecord::Base.connection.open_transactions ] ]
      expect(Disclosure::Company.count).to eq 0
    end
  end

  it "点検の照合の途中で例外になっても、先に作った資産合計の欠落の通知は送ってから、例外をそのまま伝える" do
    error = RuntimeError.new("broken chart")
    allow_any_instance_of(Charts::Builders::PlJgaapGeneral).to receive(:mismatch).and_raise(error)

    expect { call(synthetic_xbrl_xml(facts: { [ "jppfs_cor:NetSales", "CurrentYearDuration_NonConsolidatedMember" ] => 100 })) }
      .to raise_error(error)
    expect(notices.map(&:first)).to eq [ [ "primary statement missing bs.assets: S0000001 (jgaap_general)" ] ]
  end

  it "原本のファイルは取込の後に消す（例外で終わったときも）。途中の例外は包み直さずにそのまま伝える" do
    error = RuntimeError.new("broken DEI")
    dei_extractor = instance_double(Ingestion::DeiExtractor)
    allow(dei_extractor).to receive(:extract).and_raise(error)
    client = FakeEdinetClient.new("S0000001" => synthetic_xbrl_xml)

    Dir.mktmpdir do |work_dir|
      described_class.new(client: client).call(doc_id: "S0000001", work_dir: work_dir)
      expect(Dir.children(work_dir)).to eq []

      expect { described_class.new(client: client, dei_extractor: dei_extractor).call(doc_id: "S0000001", work_dir: work_dir) }
        .to raise_error(error)
      expect(Dir.children(work_dir)).to eq []
    end
  end
end
