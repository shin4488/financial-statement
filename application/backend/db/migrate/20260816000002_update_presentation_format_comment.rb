# 形式（presentation_format）の一覧はコードの Ingestion::FormatRegistry::ALL が正で、
# 業種対応で形式が増えるたびにカラムコメントを追随させないよう、コメントを一覧の列挙から参照に変える
class UpdatePresentationFormatComment < ActiveRecord::Migration[7.2]
  def up
    change_column_comment :financial_statements, :presentation_format,
      "表示形式（値の一覧はコードの Ingestion::FormatRegistry::ALL を参照）"
  end

  def down
    change_column_comment :financial_statements, :presentation_format,
      "表示形式 jgaap_general/jgaap_bank/ifrs_classified/ifrs_liquidity/unsupported"
  end
end
