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
end
