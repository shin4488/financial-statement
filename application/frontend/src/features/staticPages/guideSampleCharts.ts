import type {
  Segment,
  StackChart,
  WaterfallChartData,
} from '@/shared/financialCharts';

// 「財務三表の読み方」ページに載せる説明用の架空データ。
// 実際のカードと同じチャート部品（shared/financialCharts）に流し込み、
// 一覧で表示されるグラフと同じ見た目で読み方を説明できるようにする。
// key・label・colorRoleはバックエンドの日本基準・一般事業会社のBuilderが出す値に合わせている
// （説明が実物と食い違わないように）。金額は「総資産1,000億円・売上高1,000億円の会社」の例
const oku = 100_000_000; // 1億円

function seg(
  key: string,
  label: string,
  amountOku: number,
  ratio: number,
  colorRole: string,
): Segment {
  const amount = amountOku * oku;
  return { key, label, amount, signedAmount: amount, ratio, colorRole };
}

export const sampleBalanceSheet: StackChart = {
  renderable: true,
  note: null,
  bars: [
    {
      label: '借方',
      segments: [
        seg('currentAssets', '流動資産', 400, 40, 'asset1'),
        seg('tangible', '有形固定資産', 300, 30, 'asset2'),
        seg('intangible', '無形固定資産', 100, 10, 'asset3'),
        seg('investments', '投資その他資産', 200, 20, 'asset4'),
      ],
    },
    {
      label: '貸方',
      segments: [
        seg('currentLiabilities', '流動負債', 300, 30, 'liability1'),
        seg('fixedLiabilities', '固定負債', 250, 25, 'liability2'),
        seg('equity', '純資産', 450, 45, 'equity'),
      ],
    },
  ],
};

export const sampleProfitLoss: StackChart = {
  renderable: true,
  note: null,
  bars: [
    {
      label: '借方',
      segments: [
        seg('costOfSales', '売上原価', 600, 60, 'expense1'),
        seg('sga', '販売一般管理費', 300, 30, 'expense2'),
        seg('operatingProfit', '営業利益', 100, 10, 'profit'),
      ],
    },
    {
      label: '貸方',
      segments: [seg('revenue', '売上', 1000, 100, 'revenue')],
    },
  ],
};

// 期首100億 → 営業+30億 → 投資-20億 → 財務-10億 → 期末100億
export const sampleCashFlow: WaterfallChartData = {
  renderable: true,
  note: null,
  steps: [
    { key: 'cashBegin', label: '期首残', amount: 100 * oku, kind: 'balance' },
    { key: 'operating', label: '営業CF', amount: 30 * oku, kind: 'flow' },
    { key: 'investing', label: '投資CF', amount: -20 * oku, kind: 'flow' },
    { key: 'financing', label: '財務CF', amount: -10 * oku, kind: 'flow' },
    { key: 'cashEnd', label: '期末残', amount: 100 * oku, kind: 'balance' },
  ],
};
