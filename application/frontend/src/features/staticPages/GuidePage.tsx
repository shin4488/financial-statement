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
      description="貸借対照表（BS）・損益計算書（PL）・キャッシュフロー計算書（CF）の基本と、investeeのグラフ（積み上げ棒グラフ・ウォーターフォール）の見方、キャッシュフロー8パターンの意味を解説します。"
      path={siteRoutes.guide}
    >
      <P>
        investeeは、上場企業が提出した有価証券報告書の財務三表を、比べやすいグラフに描き直して表示しています。このページでは、財務三表そのものの基本と、investeeのグラフの見方を説明します。会計の予備知識がなくても読めるように書いています。
      </P>

      <Section title="財務三表とは">
        <P>
          企業の財政状態と経営成績を表す3種類の書類です。上場企業は法律に基づいて事業年度ごとにこれを開示しており、investeeはその開示データをそのまま使っています。
        </P>
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
          左側（借方）に資産、右側（貸方）に負債と純資産を並べたもので、
          <strong>左右の合計は必ず一致します</strong>
          （資産 = 負債 +
          純資産）。investeeはこれを左右2本の積み上げ棒グラフで描きます。左右の高さが揃うこと自体が、データが正しく取れていることの確認にもなっています。
        </P>
        <SampleChartCard title="貸借対照表の表示例">
          <StackedBarChart chart={sampleBalanceSheet} height={320} />
        </SampleChartCard>
        <Bullets>
          <Bullet>
            <strong>左のバー（借方）</strong>
            は資産の内訳です。上から流動資産（1年以内に現金化されるもの）、有形固定資産（工場・店舗など）、無形固定資産（ソフトウェア・のれんなど）、投資その他の資産の順に積み上がります
          </Bullet>
          <Bullet>
            <strong>右のバー（貸方）</strong>
            は資金の調達源泉です。流動負債（1年以内に支払期限が来るもの）、固定負債（長期の借入など）、純資産（返す必要のない自己資本）の順です
          </Bullet>
          <Bullet>
            セグメントの数値は総資産に対する構成比（%）です。実際の金額（百万円単位）はマウスオーバー、またはタップで表示されます
          </Bullet>
          <Bullet>
            純資産の割合は、いわゆる自己資本比率にあたります。一般に高いほど借入への依存が小さく財務の安定性が高いと見なされますが、適正な水準は業種によって大きく異なります（銀行のように負債が大半を占めるのが普通の業種もあります）
          </Bullet>
          <Bullet>
            流動資産と流動負債の大小は、短期の支払能力の目安になります
          </Bullet>
          <Bullet>
            負債が資産を上回り純資産がマイナスになった状態を債務超過と呼びます。該当する企業では3本目のバー「債務超過」が現れ、マイナス分の大きさが分かるようにしています
          </Bullet>
          <Bullet>
            借方と貸方の合計が1割を超えてずれているデータは、誤解を招くグラフを出すよりも表示しない方がよいと考え、チャートを表示せずその旨を示します
          </Bullet>
        </Bullets>
      </Section>

      <Section title="損益計算書（PL）の見方">
        <P>
          「売上 − 費用 =
          利益」の構造です。売上を「何に使ったか（費用）」と「残った儲け（利益）」に分解して左右に並べると、BSと同じく左右の合計が一致するため、同じ積み上げ棒グラフ2本で描けます。
        </P>
        <SampleChartCard title="損益計算書の表示例">
          <StackedBarChart chart={sampleProfitLoss} height={320} />
        </SampleChartCard>
        <Bullets>
          <Bullet>
            <strong>左のバー（借方）</strong>
            は売上原価（商品・サービスを作るのにかかった費用）、販売費及び一般管理費（売る・管理するのにかかった費用）、営業利益（差し引きで残った本業の儲け）です
          </Bullet>
          <Bullet>
            <strong>右のバー（貸方）</strong>
            は売上高です。売上より費用が大きい（営業損失）場合は、損失が右側に積まれて高さが揃います
          </Bullet>
          <Bullet>
            数値は売上高を100としたときの割合（%）です。営業利益の%がそのまま営業利益率、売上原価の%が原価率にあたります
          </Bullet>
          <Bullet>
            原価率が高く販管費率が低い、あるいはその逆といった構成の違いは、業種やビジネスモデルの違いを表します。同業他社と並べて比べると特徴が見えやすくなります
          </Bullet>
          <Bullet>
            investeeが表示する利益は本業の儲けを表す営業利益までです（IFRS採用企業は税引前利益、銀行は経常利益）。純利益などそれより下の段階は表示していません
          </Bullet>
        </Bullets>
      </Section>

      <Section title="キャッシュフロー計算書（CF）の見方">
        <P>
          PLの利益は会計上の計算値で、現金の動きとは一致しません（掛け売り・減価償却などが差を生みます）。CFは現金の増減だけを3つの活動に分けて示すもので、investeeは期首の現金残高から期末残高までを階段状のウォーターフォールグラフで描きます。
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
            「期首残」「期末残」は現金残高そのもの、間の3つはその期の増減です。増加は青系、減少は赤系で塗り分けています
          </Bullet>
          <Bullet>
            増減のバーは直前の残高の高さから始まるので、現金がどこで増えてどこで減ったかを一目で追えます
          </Bullet>
          <Bullet>
            期末残は開示された実際の残高を描いています。為替換算差額などがあるため「期首
            + 3区分の合計」と厳密には一致しないことがあります
          </Bullet>
          <Bullet>
            数値の単位は百万円です（BS・PLと違い、比率ではなく金額をそのまま描いています。百万円未満の小さな金額だけ千円単位で表示します）
          </Bullet>
        </Bullets>
      </Section>

      <Section title="キャッシュフローの8パターン">
        <P>
          営業・投資・財務CFの正負（↑/↓）の組合せは8通りあり、企業の状況を推し量る古典的な見方が知られています。investeeではこの8通りに名前を付け、一覧画面の「キャッシュフロー」で絞り込みに使えるようにしています。
        </P>
        <CashFlowPatternTable />
        <P>
          解釈はあくまで一般的な財務分析の見方です。創業期・成長期の企業が「勝負型」になるのは自然なことですし、成熟企業が「健全型」でも本業が縮小していることもあります。パターン単独で企業の良し悪しを判断せず、BS・PLや複数年の推移とあわせて見てください。
        </P>
      </Section>

      <Section title="3表のつながり">
        <Bullets>
          <Bullet>
            PLの利益は、配当などで社外に出ていく分を除いて純資産（利益剰余金）として蓄積され、BSの右下を厚くしていきます
          </Bullet>
          <Bullet>CFの期末残高は、BSの現金及び預金にほぼ対応します</Bullet>
          <Bullet>
            「利益は出ているのに営業CFがマイナス」という組合せは、売掛金や在庫の増加で現金が回収できていないサインのことがあります。PLとCFを見比べる価値がここにあります
          </Bullet>
        </Bullets>
      </Section>

      <Section title="会計基準・業種による表示の違い">
        <P>
          財務諸表の作り方のルール（会計基準）と業種によって、科目の名前や利益の段階が変わります。investeeはカードの見出しに会計基準（日本基準以外のとき）と連結/単体を表示しています。
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
              'IFRS',
              'グローバル企業を中心に採用が増加',
              '流動/非流動に区分、または流動性の高い順に配列。純資産は「資本」',
              '売上収益 − 費用 → 税引前利益',
              '対応（連結）',
            ],
            [
              '米国基準・日本基準の保険業など',
              '一部の企業',
              '—',
              '—',
              'グラフの代わりに未対応の旨を表示',
            ],
          ]}
        />
        <Bullets>
          <Bullet>
            IFRS採用企業でも単体（親会社のみ）の財務諸表は日本基準で作成されます。investeeは子会社を含む企業グループ全体の数値である連結を優先し、連結を作成していない企業のみ単体を表示します
          </Bullet>
          <Bullet>
            IFRSでは営業利益の開示が任意で企業差が大きいため、企業間で比較できる利益の段階として税引前利益を使っています
          </Bullet>
        </Bullets>
      </Section>

      <Section title="investeeの使い方">
        <SubSection title="探す">
          <Bullets>
            <Bullet>
              画面上部の「証券コードで検索」に4桁の証券コードを入力すると、その企業の全期分のカードに絞り込めます。複数入力すれば並べて比較できます
            </Bullet>
            <Bullet>
              「キャッシュフロー」で上記8パターンを選ぶと、そのパターンに当てはまる企業だけを一覧できます
            </Bullet>
            <Bullet>
              何も指定しなければ、有価証券報告書の提出日が新しい順に表示され、下にスクロールすると続きが自動で読み込まれます
            </Bullet>
          </Bullets>
        </SubSection>
        <SubSection title="見る">
          <Bullets>
            <Bullet>
              各カードはBS → PL →
              CFの順にグラフを切り替えられます。「自動切替」にチェックを入れると6秒ごとに自動で切り替わり、グラフに触れている間は止まります
            </Bullet>
            <Bullet>
              カードの見出しは「証券コード :
              会計期間（連結/単体）」です。企業名は有価証券報告書の提出時点の社名で、クリックすると株探の銘柄ページを開きます
            </Bullet>
            <Bullet>
              データは毎日更新され、前日にEDINETへ提出された有価証券報告書が翌朝には反映されます
            </Bullet>
          </Bullets>
        </SubSection>
      </Section>

      <Typography variant="body2" color="text.secondary" sx={{ mt: 4 }}>
        このページの説明は一般的な財務分析の考え方をまとめたもので、特定の銘柄の売買を推奨するものではありません。データの出典・免責事項は
        <InternalLink to={siteRoutes.about}>このサイトについて</InternalLink>
        をご覧ください。
      </Typography>
    </StaticPageLayout>
  );
}
