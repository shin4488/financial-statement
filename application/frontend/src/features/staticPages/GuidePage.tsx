import React from 'react';
import {
  Box,
  Card,
  CardContent,
  CardHeader,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import { StackedBarChart, WaterfallChart } from '@/shared/financialCharts';
import { StaticPageLayout } from '@/features/siteLayout/StaticPageLayout';
import { siteRoutes } from '@/features/siteLayout/siteRoutes';
import { CashFlowTypeValue, cashFlowTypes } from '@/constants/values';
import {
  Definition,
  DefinitionTable,
  Bullet,
  Bullets,
  InternalLink,
  P,
  Section,
  SimpleTable,
  SubSection,
  wideTableMinWidth,
} from './pageParts';
import {
  sampleBalanceSheet,
  sampleCashFlow,
  sampleProfitLoss,
} from './guideSampleCharts';

// 説明用チャートを一覧のカードと同じ枠（Card）で見せ、実物と同じ見た目で読み方を示す
function SampleChartCard({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <Card variant="outlined" sx={{ my: 2 }}>
      <CardHeader
        title={title}
        titleTypographyProps={{ variant: 'subtitle1' }}
        subheader="説明用の架空データ（総資産・売上高がともに1,000億円の会社の例）。実際の画面と同じく、グラフに触れると金額が表示されます"
        subheaderTypographyProps={{ variant: 'caption' }}
      />
      <CardContent sx={{ textAlign: 'center' }}>{children}</CardContent>
    </Card>
  );
}

// CFパターン8種の一般的な解釈。名前と矢印は一覧画面の絞り込みと同じ定数（cashFlowTypes）から
// 取り、説明文だけをここで持つ（画面の選択肢と説明が食い違わないようにする）
const cashFlowPatternNotes: Partial<Record<CashFlowTypeValue, string>> = {
  healthy: '本業で稼ぎ、投資と借入返済に回せている',
  active: '本業の稼ぎに加えて資金調達し、積極投資している',
  stable: '稼ぎながら資産売却・調達もして現金を厚くしている',
  improving: '稼ぎと資産売却で借入返済を進めている',
  competitive: '本業は赤字だが、調達した資金で投資している',
  restructuring: '本業の赤字を資産売却で補い、返済も進めている',
  reconsidering: '全区分で現金が流出。過去の蓄えで凌いでいる状態',
  rescuing: '本業の赤字を資産売却と外部調達の両方で支えている',
};

function CashFlowPatternTable() {
  const patterns = cashFlowTypes.filter((item) => item.value !== 'none');
  return (
    <TableContainer component={Paper} variant="outlined" sx={{ mb: 2 }}>
      <Table size="small" sx={{ minWidth: wideTableMinWidth }}>
        <TableHead>
          <TableRow>
            {['パターン', '営業', '投資', '財務', '一般的な解釈'].map(
              (cell) => (
                <TableCell key={cell} sx={{ fontWeight: 'bold' }}>
                  {cell}
                </TableCell>
              ),
            )}
          </TableRow>
        </TableHead>
        <TableBody>
          {patterns.map((item) => (
            <TableRow key={item.value}>
              <TableCell>{item.text}</TableCell>
              {item.raises_or_falls.map((arrow, index) => (
                <TableCell key={index}>
                  {/* 矢印の配色は一覧画面の絞り込みメニューと同じ */}
                  <Box
                    component="span"
                    color={arrow === '↓' ? 'negative.main' : 'positive.main'}
                    fontWeight="bold"
                  >
                    {arrow}
                  </Box>
                </TableCell>
              ))}
              <TableCell>{cashFlowPatternNotes[item.value]}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}

export default function GuidePage() {
  return (
    <StaticPageLayout
      title="財務三表の読み方"
      description="財務三表のグラフとROE・ROAの読み方、キャッシュフローの8パターン、企業の探し方を紹介します。"
      path={siteRoutes.guide}
    >
      <P>
        財務三表のグラフとROE・ROAで、企業の資産・利益・お金の流れを確認できます。
      </P>

      <Section title="財務三表とは">
        <P>企業の資産、利益、現金の動きをまとめた3種類の書類です。</P>
        <SimpleTable
          head={['表', '正式名称', '何を表すか', '性質']}
          rows={[
            [
              'BS',
              '貸借対照表（IFRSでは財政状態計算書）',
              'ある時点で、企業が何を持っていて（資産）、その調達源泉は何か（負債・純資産）',
              'ある一時点の残高',
            ],
            [
              'PL',
              '損益計算書',
              '1年間で、どれだけ売り上げ、費用を使い、いくら儲けたか',
              '1年間の集計',
            ],
            [
              'CF',
              'キャッシュフロー計算書',
              '1年間で、現金がどの活動でいくら増減したか',
              '1年間の集計',
            ],
          ]}
        />
      </Section>

      <Section title="貸借対照表（BS）の見方">
        <P>
          左は資産、右は負債と純資産です。<strong>資産 = 負債 + 純資産</strong>
          なので、左右の合計は一致します。
        </P>
        <SampleChartCard title="貸借対照表の表示例">
          <StackedBarChart chart={sampleBalanceSheet} height={320} />
        </SampleChartCard>
        <Bullets>
          <Bullet>
            <strong>左の棒：</strong>
            現金・在庫・設備など、持っている資産の内訳です。
          </Bullet>
          <Bullet>
            <strong>右の棒：</strong>借入などの負債と、純資産の内訳です。
          </Bullet>
          <Bullet>
            数値は総資産に対する割合です。グラフに触れると金額が表示されます。
          </Bullet>
          <Bullet>
            純資産の割合や、流動資産と流動負債のバランスを同業他社と比べてみてください。
          </Bullet>
          <Bullet>
            純資産がマイナスの場合は、3本目の棒「債務超過」で示します。
          </Bullet>
        </Bullets>
      </Section>

      <Section title="損益計算書（PL）の見方">
        <P>
          売上から費用を引くと利益が残ります。グラフでは、売上とその内訳を左右に並べています。
        </P>
        <SampleChartCard title="損益計算書の表示例">
          <StackedBarChart chart={sampleProfitLoss} height={320} />
        </SampleChartCard>
        <Bullets>
          <Bullet>
            <strong>左の棒：</strong>
            売上原価、販売費及び一般管理費、営業利益です。
          </Bullet>
          <Bullet>
            <strong>右の棒：</strong>
            売上高です。営業赤字の場合は損失も右側に表示します。
          </Bullet>
          <Bullet>
            数値は売上高に対する割合です。営業利益の割合が営業利益率にあたります。
          </Bullet>
          <Bullet>
            同業他社と比べると、費用のかかり方や利益の残り方の違いが分かります。
          </Bullet>
          <Bullet>
            PLグラフの利益は、日本基準の一般企業では営業利益、銀行・保険では経常利益、IFRSでは税引前利益です。
          </Bullet>
        </Bullets>
      </Section>

      <Section title="キャッシュフロー計算書（CF）の見方">
        <P>
          現金が何によって増え、何によって減ったかを示します。売上代金の入金時期などにより、PLの利益とは一致しません。
        </P>
        <SampleChartCard title="キャッシュフロー計算書の表示例">
          <WaterfallChart chart={sampleCashFlow} height={320} />
        </SampleChartCard>
        <SimpleTable
          head={['区分', '内容', 'プラスの意味', 'マイナスの意味']}
          rows={[
            [
              '営業CF',
              '本業での現金の出入り',
              '本業で現金を稼げている',
              '本業で現金が流出している',
            ],
            [
              '投資CF',
              '設備・株式などへの投資と回収',
              '資産を売却して現金を回収した',
              '将来のために投資している',
            ],
            [
              '財務CF',
              '借入・返済・増資・配当',
              '資金を調達している',
              '借入返済や配当で流出している',
            ],
          ]}
        />
        <Bullets>
          <Bullet>
            期首残高から、営業・投資・財務の順に現金の増減を追います。青系は増加、赤系は減少です。
          </Bullet>
          <Bullet>
            為替の影響などにより、3区分の増減だけでは期末残高と一致しない場合があります。
          </Bullet>
          <Bullet>
            単位は百万円です。百万円未満の小さな金額は千円で表示します。
          </Bullet>
        </Bullets>
      </Section>

      <Section title="ROE・ROAの見方">
        <P>
          ROEは自己資本に対して、ROAは総資産に対して、どれだけ純利益を得たかを示します。CFの次のカードで確認できます。
        </P>
        <SimpleTable
          head={['指標', 'このサイトの計算式']}
          rows={[
            ['ROE', '純利益 ÷ 平均自己資本 × 100（%）'],
            ['ROA', '純利益 ÷ 平均総資産 × 100（%）'],
            ['売上高純利益率', '純利益 ÷ 売上高 × 100（%）'],
            ['総資産回転率', '売上高 ÷ 平均総資産（回）'],
            ['財務レバレッジ', '平均総資産 ÷ 平均自己資本（倍）'],
          ]}
        />
        <SubSection title="内訳の読み方">
          <DefinitionTable>
            <Definition term="収益性">
              売上からどれだけ純利益を残せたか
            </Definition>
            <Definition term="効率性">
              資産に対してどれだけ売上を生んだか
            </Definition>
            <Definition term="健全性">
              自己資本に対して総資産が何倍あるか（財務レバレッジ）
            </Definition>
          </DefinitionTable>
          <P>
            色は項目の区別です。レバレッジが高いほど健全という意味ではありません。
          </P>
          <P>
            ROE = 売上高純利益率 × 総資産回転率 ×
            財務レバレッジ。ROAは最初の2つの積です。
          </P>
          <P>
            カードでは回転率・レバレッジも%で表示します（80% = 0.80回、250% =
            2.50倍）。丸めのため、表示値の積とROE・ROAは少しずれる場合があります。
          </P>
        </SubSection>
        <SubSection title="計算条件">
          <Bullets>
            <Bullet>
              残高は同じ有価証券報告書の期首・期末の平均を使います。期首がなければ、期末だけで代用しません。
            </Bullet>
            <Bullet>
              連結の純利益は親会社株主に帰属する利益です。自己資本には非支配株主持分や新株予約権などを含めません。
            </Bullet>
            <Bullet>
              赤字はマイナスで表示し、1年未満の決算でも年率換算しません。他サイトとは利益の種類や計算期間が異なる場合があります。
            </Bullet>
          </Bullets>
        </SubSection>
        <SubSection title="データが足りないとき">
          <DefinitionTable>
            <Definition term="データなし">計算に必要な値が不足</Definition>
            <Definition term="算出不可">分母が0以下</Definition>
            <Definition term="企業公表値">
              計算データが不足するため、書類に記載されたROEを表示
            </Definition>
            <Definition term="—">
              ROAの計算に使わない財務レバレッジ欄
            </Definition>
          </DefinitionTable>
          <P>
            公表ROEは同じ書類・会計基準・連結区分の値を使います。計算条件は書類の注記に従い、「算出不可」の場合は補完しません。
          </P>
          <P>
            売上高がなくても利益と残高があればROE・ROAは計算できます。公表ROEからの逆算や、銀行・保険の経常収益による売上高の代用はしません。
          </P>
        </SubSection>
      </Section>

      <Section title="キャッシュフローの8パターン">
        <P>
          営業・投資・財務CFのプラスとマイナスで8種類に分けています。一覧画面の「キャッシュフロー」で絞り込めます。
        </P>
        <CashFlowPatternTable />
        <P>
          パターンだけで良し悪しは判断できません。BS・PLや過去の推移もあわせて確認してください。
        </P>
      </Section>

      <Section title="3表のつながり">
        <Bullets>
          <Bullet>
            PLの利益は、配当などを除いてBSの利益剰余金に積み上がります。
          </Bullet>
          <Bullet>
            CFの期末残高はBSの現金・預金と関係しますが、集計範囲は異なる場合があります。
          </Bullet>
          <Bullet>
            利益が出ていても、売掛金や在庫が増えると現金が減ることがあります。PLと営業CFを見比べてください。
          </Bullet>
        </Bullets>
      </Section>

      <Section title="会計基準・業種による表示の違い">
        <P>
          会計基準や業種によって、科目と利益の種類が変わります。カードの見出しで会計基準と連結・単体を確認できます（日本基準の表記は省略）。
        </P>
        <SimpleTable
          head={['形式', '対象', 'BSの科目', 'PLの利益', '表示']}
          rows={[
            [
              '日本基準・一般事業会社',
              '製造・小売・ITなど大半の企業',
              '流動/固定に区分',
              '売上高 − 費用 → 営業利益',
              '対応',
            ],
            [
              '日本基準・銀行',
              '銀行',
              '貸出金・預金など業種固有の科目',
              '経常収益 − 経常費用 → 経常利益',
              '対応',
            ],
            [
              '日本基準・保険',
              '生命保険・損害保険',
              '有価証券・保険契約準備金など業種固有の科目',
              '経常収益 − 経常費用 → 経常利益',
              '対応',
            ],
            [
              'IFRS',
              'グローバル企業を中心に採用が増加',
              '流動/非流動に区分、または流動性の高い順に配列。純資産は「資本」',
              '売上収益 − 費用 → 税引前利益',
              '対応（連結）',
            ],
            [
              '米国基準など',
              '一部の企業',
              '—',
              '—',
              'グラフの代わりに未対応の旨を表示',
            ],
          ]}
        />
        <Bullets>
          <Bullet>
            子会社を含む連結の財務諸表を優先し、連結がない企業は単体を表示します。
          </Bullet>
          <Bullet>IFRS採用企業でも、単体の財務諸表は日本基準です。</Bullet>
          <Bullet>
            2019年3月期より前のIFRSの書類はBSの詳細データがなく、PL・CFのみ表示します。
          </Bullet>
        </Bullets>
      </Section>

      <Section title="investeeの使い方">
        <SubSection title="探す">
          <Bullets>
            <Bullet>
              「証券コードで検索」に4桁のコード（例：7203、391A）を入力します。複数の企業を並べて比較できます。
            </Bullet>
            <Bullet>「キャッシュフロー」で、8パターンから絞り込めます。</Bullet>
            <Bullet>
              指定がなければ提出日の新しい順に表示します。下へスクロールすると続きが読み込まれます。
            </Bullet>
          </Bullets>
        </SubSection>
        <SubSection title="見る">
          <Bullets>
            <Bullet>
              カードはBS → PL → CF →
              ROE・ROAの順に切り替わります。「自動切替」は6秒間隔で、カードに触れている間は止まります。
            </Bullet>
            <Bullet>
              見出しに証券コード・会計期間・連結／単体を表示します。企業名は書類提出時の社名で、クリックすると株探を開きます。
            </Bullet>
            <Bullet>
              前日にEDINETへ提出された有価証券報告書を、毎朝取り込みます。
            </Bullet>
          </Bullets>
        </SubSection>
      </Section>

      <Typography variant="body2" color="text.secondary" sx={{ mt: 4 }}>
        特定銘柄の売買を推奨するものではありません。出典・免責事項は
        <InternalLink to={siteRoutes.about}>このサイトについて</InternalLink>
        をご覧ください。
      </Typography>
    </StaticPageLayout>
  );
}
