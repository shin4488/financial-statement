import React from 'react';
import { StaticPageLayout } from '@/features/siteLayout/StaticPageLayout';
import { siteRoutes } from '@/features/siteLayout/siteRoutes';
import {
  Bullet,
  Bullets,
  Definition,
  DefinitionTable,
  ExternalLink,
  InternalLink,
  P,
  Section,
} from './pageParts';

export default function AboutPage() {
  return (
    <StaticPageLayout
      title="このサイトについて"
      description="investeeは、上場企業が提出した有価証券報告書の財務三表（貸借対照表・損益計算書・キャッシュフロー計算書）をEDINETから毎日取得し、グラフで一覧・比較できる無料のWebサービスです。データの出典・更新・免責事項・運営者情報を掲載しています。"
      path={siteRoutes.about}
    >
      <Section title="investeeとは">
        <P>
          investee（インベスティー）は、日本の上場企業が提出した有価証券報告書の財務三表（貸借対照表・損益計算書・キャッシュフロー計算書）を、比べやすいグラフにして一覧表示する無料のWebサービスです。会員登録は不要で、どなたでも利用できます。
        </P>
        <P>
          有価証券報告書の数表は、慣れていないと数字の羅列に見えて全体像がつかみにくいものです。investeeは各社の財務三表を同じ形のグラフに描き直し、カードとして並べることで、「この会社はどこにお金を使い、どう稼ぎ、現金がどう動いたか」を一目で見比べられるようにしています。
        </P>
        <Bullets>
          <Bullet>
            貸借対照表と損益計算書は、借方・貸方の2本の積み上げ棒グラフとして構成比（%）で表示します
          </Bullet>
          <Bullet>
            キャッシュフロー計算書は、期首残高から期末残高までの増減をウォーターフォールグラフで表示します
          </Bullet>
          <Bullet>
            証券コードで企業を絞り込んだり、営業・投資・財務キャッシュフローの正負の組合せ（8パターン）で企業を探したりできます
          </Bullet>
          <Bullet>
            グラフの見方は
            <InternalLink to={siteRoutes.guide}>財務三表の読み方</InternalLink>
            で詳しく説明しています
          </Bullet>
        </Bullets>
      </Section>

      <Section title="データの出典と更新">
        <DefinitionTable>
          <Definition term="出典">
            金融庁の電子開示システム
            <ExternalLink href="https://disclosure2.edinet-fsa.go.jp/">
              EDINET
            </ExternalLink>
            に提出された有価証券報告書（XBRLデータ）
          </Definition>
          <Definition term="対象">
            上場企業が事業年度ごとに提出する有価証券報告書。訂正有価証券報告書が提出された場合は、同じ会計期間のデータを訂正後の内容で上書きします
          </Definition>
          <Definition term="更新">
            毎日自動で、前日にEDINETへ提出された報告書を取り込みます
          </Definition>
          <Definition term="連結・単体">
            子会社を含む企業グループ全体の数値（連結）を優先し、連結財務諸表を作成していない企業のみ単体の数値を表示します
          </Definition>
          <Definition term="会計基準">
            日本基準（一般事業会社・銀行・保険）とIFRS（連結）に対応しています。米国基準など未対応の形式は、グラフの代わりにその旨を表示します
          </Definition>
        </DefinitionTable>
      </Section>

      <Section title="数値の扱いと注意点">
        <Bullets>
          <Bullet>
            数値は提出データ（XBRL）から機械的に抽出しており、人手による検証は行っていません。提出データ側の誤りや、抽出処理の不具合により、実際の開示内容と異なる場合があります
          </Bullet>
          <Bullet>
            グラフでは主要な科目に集約して表示しています。細かい科目の内訳は、EDINETまたは各社の開示資料をご確認ください
          </Bullet>
          <Bullet>
            借方と貸方の合計が大きくずれているなど、明らかに整合しないデータは、誤解を招くグラフを出さないためチャートを表示しません
          </Bullet>
          <Bullet>
            企業名は有価証券報告書の提出時点の社名を表示しています。社名変更があった企業では、過去の年度が当時の社名で表示されます
          </Bullet>
        </Bullets>
      </Section>

      <Section title="免責事項">
        <P>
          当サイトは情報の提供のみを目的としており、特定の金融商品の売買や投資を推奨・勧誘するものではありません。掲載している情報の正確性・完全性・最新性について保証するものではなく、当サイトの情報を利用して行った投資判断やその結果について、運営者は一切の責任を負いません。投資に関する最終的な判断は、ご自身の責任で行ってください。
        </P>
        <P>
          当サイトからリンクしている外部サイト（EDINET・株探など）の内容については、運営者は責任を負いません。
        </P>
      </Section>

      <Section title="運営者情報">
        <DefinitionTable>
          <Definition term="サイト名">investee（インベスティー）</Definition>
          <Definition term="URL">https://investee.info</Definition>
          <Definition term="運営者">
            個人（ソフトウェアエンジニア）が開発・運営しています
          </Definition>
          <Definition term="連絡先">
            <InternalLink to={siteRoutes.contact}>お問い合わせ</InternalLink>
            のページをご覧ください
          </Definition>
          <Definition term="利用している外部サービス">
            アクセス解析（Google Analytics）と広告配信（Google
            AdSense）を利用しています。詳細は
            <InternalLink to={siteRoutes.privacy}>
              プライバシーポリシー
            </InternalLink>
            をご覧ください
          </Definition>
        </DefinitionTable>
      </Section>
    </StaticPageLayout>
  );
}
