// バックエンドの Charts::Builders が発行する colorRole の全量。
// 「科目→色」でなく「役割→色」にすることで、形式を追加するときも科目（例: 銀行の貸出金）に
// 定義済みの役割（asset2）を割り当てるだけで一貫した見た目になる。
// このキー一覧はバックエンドと共有する契約なので、追加はバックエンドのenumと同時に行うこと
export const colorByRole: Record<string, string> = {
  asset1: '#A1C2F1', // 資産・第1階層（流動資産/現金系）
  asset2: '#5A96E3', // 資産・第2階層
  asset3: '#7286D3',
  asset4: '#576CBC',
  liability1: '#FEBBCC', // 負債・第1階層
  liability2: '#E48586',
  equity: '#8EC3B0', // 資本・純資産（債務超過時も同色。値の負はラベル・ツールチップで示す）
  revenue: '#A1C2F1', // 収益
  expense1: '#FEBBCC', // 費用（原価・経常費用・営業費用）
  expense2: '#E48586', // 費用（販管費）
  // 導出項目（その他損益（純額）など）は費用側・収益側のどちらに積まれても同じ紫にする:
  // 実在の科目（ピンク系の費用・青系の収益）と紛れず、符号で側が変わっても同一項目だと分かるように
  expense3: '#8E7AB5', // 導出項目が費用側に積まれるとき
  revenue2: '#8E7AB5', // 導出項目が収益側に積まれるとき
  profit: '#8EC3B0', // 利益
  loss: '#F7C04A', // 損失（営業損失・経常損失・税引前損失）
  spacer: 'transparent', // 債務超過バーの位置合わせ用詰め物
};

export const stackLabelColor = '#FFFFFF';

// バックエンドが未知のroleを返した場合の色（グレー）。
// このマップはBE/FE間で唯一ドリフトし得る契約点なので、undefinedのまま
// rechartsのデフォルト色で無言に描かれるより、目に見える形で気づけるようにする
const FALLBACK_COLOR = '#9E9E9E';
const warnedRoles = new Set<string>();

export function colorForRole(role: string): string {
  // hasOwnPropertyで引く: 素の[]アクセスだとroleが"constructor"等のとき
  // Object.prototypeのメンバーが色として返ってしまうため
  if (Object.prototype.hasOwnProperty.call(colorByRole, role)) {
    return colorByRole[role];
  }
  // 警告はroleごとに1回だけ（セグメント数*再レンダリングで氾濫させない）
  if (!warnedRoles.has(role)) {
    warnedRoles.add(role);
    // 契約ドリフトの検知が目的の意図的なconsole出力（UIには出しようがないため）
    // eslint-disable-next-line no-console
    console.warn(
      `[financialCharts] 未知のcolorRole "${role}" を受信。colorRoles.tsへの追加が必要（バックエンドのenumと同時に変更する契約）`,
    );
  }
  return FALLBACK_COLOR;
}
