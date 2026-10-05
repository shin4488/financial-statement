require "rails_helper"

# ExtractorやFormatDetectorのspecはXbrl::Documentをスタブで置き換えているため、
# スタブが約束している振る舞い（qname+contextでの解決・値の正規化）はここで実物に対して固定する
RSpec.describe Xbrl::Document do
  def document_from(xml)
    file = Tempfile.new([ "doc", ".xbrl" ])
    file.write(xml)
    file.close
    described_class.load(file.path)
  ensure
    file&.unlink
  end

  # 名前空間URIのタクソノミバージョン（2025-11-01の部分）は書類の提出時期で変わる
  def xbrl(body, jppfs_version: "2025-11-01")
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <xbrli:xbrl xmlns:xbrli="http://www.xbrl.org/2003/instance"
        xmlns:jppfs_cor="http://disclosure.edinet-fsa.go.jp/taxonomy/jppfs/#{jppfs_version}/jppfs_cor"
        xmlns:ext="http://example.com/jpcrp030000-asr_E00001-000">
      #{body}
      </xbrli:xbrl>
    XML
  end

  describe "#money" do
    it "外貨と円が併記される金額は、出現順やunitのIDによらず円を使う" do
      units = <<~XML
        <xbrli:unit xmlns:currency="http://www.xbrl.org/2003/iso4217" id="yen"><xbrli:measure>currency:JPY</xbrli:measure></xbrli:unit>
        <xbrli:unit xmlns:currency="http://www.xbrl.org/2003/iso4217" id="dollar"><xbrli:measure>currency:USD</xbrli:measure></xbrli:unit>
      XML
      facts = [ '<jppfs_cor:Assets contextRef="CurrentYearInstant" unitRef="dollar">100</jppfs_cor:Assets>',
                '<jppfs_cor:Assets contextRef="CurrentYearInstant" unitRef="yen">15000</jppfs_cor:Assets>' ]
      [ facts, facts.reverse ].each do |order|
        expect(document_from(xbrl(units + order.join)).money("jppfs_cor:Assets", "CurrentYearInstant")).to eq 15_000
      end
      expect(document_from(xbrl(units + facts.first)).money("jppfs_cor:Assets", "CurrentYearInstant")).to be_nil
    end

    it "qnameとコンテキストで金額を引ける。名前空間URIのバージョン年度が違っても同じqnameで引ける" do
      aggregate_failures do
        [ "2025-11-01", "2019-11-01" ].each do |version|
          doc = document_from(xbrl(%(<jppfs_cor:Assets contextRef="CurrentYearInstant">100</jppfs_cor:Assets>),
                                   jppfs_version: version))
          expect(doc.money("jppfs_cor:Assets", "CurrentYearInstant")).to eq 100
        end
      end
    end

    it "「開示なし」と「0円」を区別する: タグ・数値でない値はnil、0は0" do
      doc = document_from(xbrl(<<~BODY))
        <jppfs_cor:Assets contextRef="CurrentYearInstant">0</jppfs_cor:Assets>
        <jppfs_cor:Liabilities contextRef="CurrentYearInstant">数値でないテキスト</jppfs_cor:Liabilities>
        <jppfs_cor:NetAssets contextRef="CurrentYearInstant"></jppfs_cor:NetAssets>
      BODY
      aggregate_failures do
        expect(doc.money("jppfs_cor:Assets", "CurrentYearInstant")).to eq 0
        expect(doc.money("jppfs_cor:Liabilities", "CurrentYearInstant")).to be_nil # to_iなら0になってしまう値
        expect(doc.money("jppfs_cor:NetAssets", "CurrentYearInstant")).to be_nil
        expect(doc.money("jppfs_cor:Assets", "Prior1YearInstant")).to be_nil # コンテキスト違いは別のfact
        expect(doc.money("jppfs_cor:CashAndDeposits", "CurrentYearInstant")).to be_nil
      end
    end

    it "DBのbigintに収まらない桁の値は「開示なし」として落とす" do
      doc = document_from(xbrl(%(<jppfs_cor:Assets contextRef="CurrentYearInstant">99999999999999999999999</jppfs_cor:Assets>)))
      expect(doc.money("jppfs_cor:Assets", "CurrentYearInstant")).to be_nil
    end

    it "企業拡張タクソノミの要素は標準タグと同名でも対象にしない" do
      doc = document_from(xbrl(%(<ext:Assets contextRef="CurrentYearInstant">999</ext:Assets>)))
      expect(doc.money("jppfs_cor:Assets", "CurrentYearInstant")).to be_nil
    end

    it "同じ要素・同じコンテキストのfactが重複したら文書の先頭側（本表側）を採用する" do
      doc = document_from(xbrl(<<~BODY))
        <jppfs_cor:Assets contextRef="CurrentYearInstant">100</jppfs_cor:Assets>
        <jppfs_cor:Assets contextRef="CurrentYearInstant">999</jppfs_cor:Assets>
      BODY
      expect(doc.money("jppfs_cor:Assets", "CurrentYearInstant")).to eq 100
    end
  end

  describe "企業拡張タグ" do
    def filer_xbrl(body)
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <xbrli:xbrl xmlns:xbrli="http://www.xbrl.org/2003/instance"
          xmlns:jppfs_cor="http://disclosure.edinet-fsa.go.jp/taxonomy/jppfs/2025-11-01/jppfs_cor"
          xmlns:jpcrp_cor="http://disclosure.edinet-fsa.go.jp/taxonomy/jpcrp/2025-11-01/jpcrp_cor"
          xmlns:asr="http://disclosure.edinet-fsa.go.jp/jpcrp030000/asr/001/E00001-000/2026-03-31/01/2026-06-20"
          xmlns:srs="http://disclosure.edinet-fsa.go.jp/jpcrp040000/asr/001/E00002-000/2015-12-31/01/2016-03-28">
        #{body}
        </xbrli:xbrl>
      XML
    end

    it "提出者の名前空間の要素は filer_ext の接頭辞で引け、同名の標準タグとは区別する" do
      doc = document_from(filer_xbrl(<<~BODY))
        <asr:Assets contextRef="CurrentYearInstant">999</asr:Assets>
        <jppfs_cor:Assets contextRef="CurrentYearInstant">100</jppfs_cor:Assets>
      BODY
      aggregate_failures do
        expect(doc.money("filer_ext:Assets", "CurrentYearInstant")).to eq 999
        expect(doc.money("jppfs_cor:Assets", "CurrentYearInstant")).to eq 100
      end
    end

    it "有報以外の様式（届出書のjpcrp040000など）の企業拡張タグも読む" do
      doc = document_from(filer_xbrl(%(<srs:BusinessRevenues contextRef="CurrentYearDuration">500</srs:BusinessRevenues>)))
      expect(doc.money("filer_ext:BusinessRevenues", "CurrentYearDuration")).to eq 500
    end

    it "標準タクソノミのjpcrp_corの要素は企業拡張タグとして扱わない" do
      doc = document_from(filer_xbrl(
        %(<jpcrp_cor:NetSalesSummaryOfBusinessResults contextRef="CurrentYearDuration">700</jpcrp_cor:NetSalesSummaryOfBusinessResults>)))
      aggregate_failures do
        expect(doc.money("jpcrp_cor:NetSalesSummaryOfBusinessResults", "CurrentYearDuration")).to eq 700
        expect(doc.money("filer_ext:NetSalesSummaryOfBusinessResults", "CurrentYearDuration")).to be_nil
        expect(doc.element_names("filer_ext")).to be_empty
      end
    end

    it "接頭辞ごとに要素名の一覧を返す" do
      doc = document_from(filer_xbrl(<<~BODY))
        <asr:BusinessRevenueSummaryOfBusinessResults contextRef="CurrentYearDuration">615</asr:BusinessRevenueSummaryOfBusinessResults>
        <asr:BusinessRevenues contextRef="CurrentYearDuration">615</asr:BusinessRevenues>
        <jppfs_cor:NetSales contextRef="CurrentYearDuration">107</jppfs_cor:NetSales>
      BODY
      expect(doc.element_names("filer_ext")).to contain_exactly("BusinessRevenueSummaryOfBusinessResults", "BusinessRevenues")
    end
  end

  describe "#text" do
    it "値を文字列のまま返し、contextRefのない要素（unit定義など）は対象にしない" do
      doc = document_from(xbrl(<<~BODY))
        <jppfs_cor:CompanyName contextRef="FilingDateInstant">テスト株式会社</jppfs_cor:CompanyName>
        <jppfs_cor:NoContext>単位定義など</jppfs_cor:NoContext>
      BODY
      aggregate_failures do
        expect(doc.text("jppfs_cor:CompanyName", "FilingDateInstant")).to eq "テスト株式会社"
        expect(doc.text("jppfs_cor:NoContext", "FilingDateInstant")).to be_nil
      end
    end
  end
  describe "#rounding_error" do
    it "decimalsから金額単位の誤差上限を取り、INFは誤差なし、未知はnilにする" do
      doc = document_from(xbrl(<<~BODY))
        <jppfs_cor:Assets contextRef="millions" decimals="-6">1000000</jppfs_cor:Assets>
        <jppfs_cor:Assets contextRef="exact" decimals="INF">1000000</jppfs_cor:Assets>
        <jppfs_cor:Assets contextRef="unknown">1000000</jppfs_cor:Assets>
        <jppfs_cor:Assets contextRef="invalid" decimals="-99999999">1000000</jppfs_cor:Assets>
      BODY
      expect(doc.rounding_error("jppfs_cor:Assets", "millions")).to eq 1_000_000
      expect(doc.rounding_error("jppfs_cor:Assets", "exact")).to eq 0
      expect(doc.rounding_error("jppfs_cor:Assets", "unknown")).to be_nil
      expect(doc.rounding_error("jppfs_cor:Assets", "invalid")).to be_nil
    end
  end
end
