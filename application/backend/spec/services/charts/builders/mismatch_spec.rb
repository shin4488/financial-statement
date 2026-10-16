require "rails_helper"

# 取込の照合（UseCases::StatementInspection）が警告に使う、Builderごとの照合の担当
RSpec.describe "Charts::Builders の照合（mismatch）" do
  no_data_note = "貸借対照表: データがない、または表示対応していないデータです。"

  # 金額の端数はどれも1（照合で許す差は、式に使った金額の数未満）
  def amounts(values)
    FinancialStatements::Amounts.new.tap do |amounts|
      values.each { |code, value| amounts.store(code, value, 1.to_d) }
    end
  end

  describe "貸借2本で描くBSは、描いたときの照合の結果を返す" do
    # どれも貸借の差が1割以内で描けるが、資産合計（1,000）が負債合計＋純資産合計（1,010）と合わない
    totals = { "bs.assets" => 1_000, "bs.liabilities" => 700, "bs.equity" => 310 }
    [
      # Builder、合計行のほかの金額、照合の結果に入る借方の科目（差額で求める科目は入らない）
      [ Charts::Builders::BsJgaapGeneral,
        { "bs.current_assets" => 400, "bs.non_current_assets" => 600, "bs.tangible_fixed_assets" => 300,
          "bs.intangible_fixed_assets" => 100, "bs.investments_and_other_assets" => 200,
          "bs.current_liabilities" => 300, "bs.non_current_liabilities" => 400 },
        { "bs.current_assets" => 400, "bs.tangible_fixed_assets" => 300, "bs.intangible_fixed_assets" => 100,
          "bs.investments_and_other_assets" => 200 } ],
      [ Charts::Builders::BsIfrsClassified,
        { "bs.current_assets" => 400, "bs.non_current_assets" => 600,
          "bs.current_liabilities" => 300, "bs.non_current_liabilities" => 400 },
        { "bs.current_assets" => 400, "bs.non_current_assets" => 600 } ],
      [ Charts::Builders::BsIfrsLiquidity, { "bs.cash_and_equivalents" => 200 }, {} ],
      [ Charts::Builders::BsJgaapBank,
        { "bs.cash_and_equivalents" => 100, "bs.loans" => 500, "bs.securities" => 200, "bs.deposits" => 600 },
        { "bs.cash_and_equivalents" => 100, "bs.loans" => 500, "bs.securities" => 200 } ],
      [ Charts::Builders::BsJgaapInsurance,
        { "bs.cash_and_equivalents" => 100, "bs.securities" => 500, "bs.loans" => 200, "bs.policy_reserves" => 600 },
        { "bs.cash_and_equivalents" => 100, "bs.securities" => 500, "bs.loans" => 200 } ]
    ].each do |builder, debit_and_credit, drawn_debit|
      it "#{builder.name.demodulize} は、借方に描いた科目と合計行の金額を返す" do
        items = amounts(debit_and_credit.merge(totals))
        expect(builder.new(items).build.renderable).to be true
        expect(builder.new(items).mismatch).to eq drawn_debit.merge(totals)
      end
    end
  end

  describe "銀行・保険のBSは、描く前の確認で描かないときは照合しない" do
    # 描けば資産合計（1,000）と負債合計＋純資産合計（1,010）が合わないことが分かる金額
    let(:bank) do
      { "bs.cash_and_equivalents" => 100, "bs.loans" => 500, "bs.securities" => 200, "bs.deposits" => 600,
        "bs.assets" => 1_000, "bs.liabilities" => 700, "bs.equity" => 310 }
    end
    let(:insurance) { bank.except("bs.deposits").merge("bs.policy_reserves" => 600) }

    it "預金がない銀行" do
      builder = Charts::Builders::BsJgaapBank.new(amounts(bank.except("bs.deposits")))
      expect(builder.build).to have_attributes(renderable: false, note: no_data_note)
      expect(builder.mismatch).to be_nil
    end

    it "預金が負債合計を超える銀行" do
      builder = Charts::Builders::BsJgaapBank.new(amounts(bank.merge("bs.deposits" => 800)))
      expect(builder.build).to have_attributes(renderable: false, note: no_data_note)
      expect(builder.mismatch).to be_nil
    end

    it "保険契約準備金がない保険" do
      builder = Charts::Builders::BsJgaapInsurance.new(amounts(insurance.except("bs.policy_reserves")))
      expect(builder.build).to have_attributes(renderable: false, note: no_data_note)
      expect(builder.mismatch).to be_nil
    end
  end

  describe "照合を上書きしないBuilderは、金額が合わなくてもnilを返す" do
    it "銀行・保険のPLは、経常費用＋経常利益が経常収益と合わなくても描き、照合しない" do
      builder = Charts::Builders::PlJgaapFinancialInstitution.new(
        amounts("pl.ordinary_revenue" => 1_000, "pl.ordinary_expenses" => 900, "pl.ordinary_profit" => 50)
      )
      expect(builder.build.renderable).to be true
      expect(builder.mismatch).to be_nil
    end

    it "経営指標の要約だけの形式は、説明文だけを返し、照合しない" do
      items = amounts("bs.assets" => 1_000, "bs.equity" => 310, "pl.revenue" => 1_000, "pl.profit_before_tax" => 50)
      [ Charts::Builders::BsIfrsSummary, Charts::Builders::BsUsgaapSummary, Charts::Builders::PlUsgaapSummary ].each do |builder|
        expect(builder.new(items).build.renderable).to be false
        expect(builder.new(items).mismatch).to be_nil
      end
    end
  end
end
