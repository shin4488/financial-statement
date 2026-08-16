# EDINET API v2 の薄いラッパ。外部I/Oをここに集約する。
# レート制限（リクエスト過多で403）のため同期・逐次実行が前提（並列化しない）
module Edinet
  class Client
    BASE = "https://disclosure.edinet-fsa.go.jp/api/v2".freeze
    # EDINETの書類種別コード。120=有価証券報告書、130=訂正有価証券報告書。
    # 訂正も取り込む理由: 数値誤りの訂正が本表に及ぶことがあり、上書き取込（冪等upsert）で
    # 最新の正しい値に置き換えるため
    ANNUAL_REPORT = "120".freeze
    AMENDED_ANNUAL_REPORT = "130".freeze

    # EDINETのdocIDは英大文字+数字8桁（例: S100YB5L）。外部由来の値をファイルパス・URLに
    # 埋め込む前の形式ガード（rakeタスクの手入力ミス対策を兼ねる）
    DOC_ID_PATTERN = /\A[A-Z0-9]{8}\z/.freeze
    # 有報zipの1エントリの展開サイズ上限（500MB）。実測の有報XBRLは数MB程度のため、
    # これを大きく超えるものは異常（zip爆弾・EDINET側の障害）として展開しない
    MAX_ENTRY_SIZE = 500 * 1024 * 1024
    # ダウンロードするzip自体のサイズ上限（500MB）。実測の有報zipは1書類あたり数MBで、
    # EDINET側の障害で巨大なレスポンスが返ってきたときに一時ディレクトリを
    # 埋め尽くさないための可用性ガード
    MAX_ZIP_SIZE = 500 * 1024 * 1024

    DocumentMeta = Struct.new(:doc_id, :sec_code, :filer_name, :doc_type_code, keyword_init: true)

    # その日に提出された上場企業の有報・訂正有報の一覧
    def list_annual_reports(date:)
      uri = URI("#{BASE}/documents.json")
      # type=2: 提出書類一覧とメタデータを返すモード（type=1はメタデータのみ）
      uri.query = URI.encode_www_form(date: date, type: 2, "Subscription-Key" => api_key)
      # get_responseでステータスを明示チェックする。Net::HTTP.getは403（レート制限）でも
      # エラーページの本文をそのまま返し、後続のJSON.parseが原因の分かりにくい例外になるため。
      # （download_xbrl側はopen-uriが非2xxでOpenURI::HTTPErrorを投げるので個別チェック不要）
      response = Net::HTTP.get_response(uri)
      unless response.is_a?(Net::HTTPSuccess)
        raise "EDINET documents.json failed: #{response.code} #{response.message} (date=#{date})"
      end
      results = JSON.parse(response.body)["results"] || []
      results.filter_map do |r|
        # secCodeなし = 非上場（投資信託・組合等の提出物）。本アプリの対象外
        next if r["secCode"].nil?
        next unless [ ANNUAL_REPORT, AMENDED_ANNUAL_REPORT ].include?(r["docTypeCode"])
        DocumentMeta.new(doc_id: r["docID"], sec_code: r["secCode"],
                         filer_name: r["filerName"], doc_type_code: r["docTypeCode"])
      end
    end

    # zipをダウンロードし、PublicDoc配下のXBRLインスタンスを展開してパスを返す（なければnil）
    # work_dir はバッチが用意した一時ディレクトリ。呼び出し側が後始末する
    def download_xbrl(doc_id:, work_dir:)
      raise ArgumentError, "invalid docID: #{doc_id.inspect}" unless doc_id.to_s.match?(DOC_ID_PATTERN)

      zip_path = File.join(work_dir, "#{doc_id}.zip")
      # 書類取得APIの type=1 は「提出本文書及び監査報告書」のzip
      uri = URI("#{BASE}/documents/#{doc_id}")
      uri.query = URI.encode_www_form(type: 1, "Subscription-Key" => api_key)
      # copy_stream: レスポンス全体をStringに載せず直接ファイルへ書く（巨大レスポンスでのOOM対策）。
      # 上限+1バイトまで読んで超過を検出する（Content-Lengthは信用せず実バイト数で判定）
      uri.open { |src| IO.copy_stream(src, zip_path, MAX_ZIP_SIZE + 1) }
      if File.size(zip_path) > MAX_ZIP_SIZE
        raise "EDINET zip too large: #{doc_id} (> #{MAX_ZIP_SIZE} bytes)"
      end

      xbrl_path = nil
      Zip::File.open(zip_path) do |zip|
        # PublicDoc = 提出本文（財務諸表を含む）。AuditDoc（監査報告書）側のXBRLは対象外。
        # 本文XBRLインスタンスは1書類に1つ。無い書類（一部の訂正有報など）はnilを返し
        # 呼び出し側が「財務データなし」としてスキップする
        entry = zip.glob("*/PublicDoc/*.xbrl").first
        next if entry.nil?
        raise "zip entry too large: #{doc_id} (#{entry.size} bytes)" if entry.size > MAX_ENTRY_SIZE
        xbrl_path = File.join(work_dir, "#{doc_id}.xbrl")
        zip.extract(entry, xbrl_path) { true } # ブロックtrue = 既存ファイルは上書き（リトライ時）
      end
      xbrl_path
    ensure
      # zipは展開後すぐ消す: 全上場企業分を貯めるとディスクを圧迫する（1書類数MB*日次数十件）
      FileUtils.rm_f(zip_path)
    end

    private
      def api_key = ENV.fetch("EDINET_API_KEY")
  end
end
