import React from 'react';
import { Typography } from '@mui/material';
import { StaticPageLayout } from '@/features/siteLayout/StaticPageLayout';
import { siteRoutes } from '@/features/siteLayout/siteRoutes';
import {
  Bullet,
  Bullets,
  ExternalLink,
  InternalLink,
  P,
  Section,
} from './pageParts';

export default function PrivacyPolicyPage() {
  return (
    <StaticPageLayout
      title="プライバシーポリシー"
      description="investee（investee.info）のプライバシーポリシー。アクセス解析（Google Analytics）・広告配信（Google AdSense）でのCookieの利用、お問い合わせフォームの入力内容の扱い、ブラウザに保存する設定、免責事項について説明します。"
      path={siteRoutes.privacy}
    >
      <P>
        investee（以下「当サイト」）は、利用者のプライバシーを尊重し、個人情報の取り扱いに配慮して運営しています。当サイトにおける情報の取得と利用について、以下のとおり定めます。
      </P>

      <Section title="1. 取得する情報">
        <P>
          当サイトは会員登録を求めておらず、閲覧にあたって利用者から個人情報を取得することはありません。ただし、当サイトの閲覧に伴い、ブラウザから自動的に送信される情報（IPアドレス、ブラウザやOSの種類、閲覧したページ、検索・クリック等の操作、参照元など）を、後述のアクセス解析および広告配信のために取得します。これらの情報だけで特定の個人を識別することはできません。お問い合わせフォームに入力いただいた情報については、後述の「お問い合わせフォームについて」のとおり取り扱います。
        </P>
      </Section>

      <Section title="2. アクセス解析ツールについて">
        <P>
          当サイトは、Googleが提供するアクセス解析ツール「Google
          Analytics」を利用しています。Google
          Analyticsは、利用状況を把握するためにCookieや類似の識別子を使用してトラフィックデータを収集します。このデータは匿名で収集されており、個人を特定するものではありません。収集されたデータはGoogleのプライバシーポリシーに基づいて管理されます。
        </P>
        <Bullets>
          <Bullet>
            Googleによるデータの利用について:{' '}
            <ExternalLink href="https://policies.google.com/technologies/partner-sites?hl=ja">
              Googleのサービスを使用するサイトやアプリから収集した情報のGoogleによる使用
            </ExternalLink>
          </Bullet>
          <Bullet>
            収集を望まない場合は、ブラウザの設定でCookieを無効にするか、
            <ExternalLink href="https://tools.google.com/dlpage/gaoptout?hl=ja">
              Google Analyticsオプトアウトアドオン
            </ExternalLink>
            をご利用ください
          </Bullet>
        </Bullets>
      </Section>

      <Section title="3. 広告配信について">
        <P>
          当サイトは、第三者配信の広告サービス「Google
          AdSense」を利用しています。Googleなどの第三者配信事業者は、利用者が当サイトや他のウェブサイトに過去にアクセスした際の情報に基づいて広告を配信するために、Cookieを使用することがあります。
        </P>
        <Bullets>
          <Bullet>
            パーソナライズ広告に使われるCookieは、Googleの
            <ExternalLink href="https://adssettings.google.com/">
              広告設定
            </ExternalLink>
            でいつでも無効にできます
          </Bullet>
          <Bullet>
            Googleの広告におけるCookieの利用の詳細は
            <ExternalLink href="https://policies.google.com/technologies/ads?hl=ja">
              広告 – ポリシーと規約 – Google
            </ExternalLink>
            をご覧ください
          </Bullet>
          <Bullet>
            Google以外の第三者配信事業者のCookieについては
            <ExternalLink href="https://www.aboutads.info/choices/">
              www.aboutads.info
            </ExternalLink>
            で無効にできます
          </Bullet>
        </Bullets>
      </Section>

      <Section title="4. ブラウザに保存する設定について">
        <P>
          当サイトは、グラフの自動切替のON/OFFといった表示設定を、利用者のブラウザ（ローカルストレージ）に保存します。この設定は表示の再現のためだけに使い、外部に送信することはありません。ブラウザのサイトデータを削除すると初期状態に戻ります。
        </P>
      </Section>

      <Section title="5. お問い合わせフォームについて">
        <P>
          当サイトのお問い合わせフォームには、Googleが提供する「Google
          フォーム」を利用しています。フォームでは氏名やメールアドレスなどの個人情報の入力を求めていません。入力いただいた内容は、お問い合わせ内容の確認と当サイトの改善のためだけに使用し、それ以外の目的で利用したり第三者に提供したりすることはありません。入力内容はGoogleのサーバに保存され、Googleのプライバシーポリシーが適用されます。
        </P>
      </Section>

      <Section title="6. 外部リンクについて">
        <P>
          当サイトには外部サイト（EDINET・株探など）へのリンクが含まれます。リンク先で取得される情報の取り扱いは各サイトの方針に従うものとし、当サイトは責任を負いません。
        </P>
      </Section>

      <Section title="7. 免責事項">
        <P>
          当サイトに掲載する情報は、公開されている開示データを機械的に処理したもので、正確性・完全性・最新性を保証するものではありません。当サイトの情報を利用したことによる損害について、運営者は一切の責任を負いません。当サイトは投資助言を行うものではなく、投資の最終判断はご自身の責任で行ってください。詳細は
          <InternalLink to={siteRoutes.about}>このサイトについて</InternalLink>
          をご覧ください。
        </P>
      </Section>

      <Section title="8. 本ポリシーの変更">
        <P>
          本ポリシーの内容は、法令の変更や利用する外部サービスの変更に応じて、予告なく改定することがあります。改定後の内容は本ページに掲載した時点で効力を持つものとします。
        </P>
      </Section>

      <Section title="9. お問い合わせ">
        <P>
          本ポリシーに関するご質問は
          <InternalLink to={siteRoutes.contact}>お問い合わせ</InternalLink>
          のページからご連絡ください。
        </P>
      </Section>

      <Typography variant="body2" color="text.secondary" sx={{ mt: 4 }}>
        制定日: 2026年8月16日
      </Typography>
    </StaticPageLayout>
  );
}
