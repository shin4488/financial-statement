import React from 'react';
import { Box, Typography } from '@mui/material';
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

// お問い合わせフォーム（Googleフォーム）の埋め込みURL
// （フォーム編集画面の「送信」→「<>」タブに出る iframe の src。末尾の ?embedded=true が埋め込み用）。
// Googleフォームにする理由: メールアドレス等の個人情報をサイトに載せずに連絡を受けられ、
// スパム対策と回答の保管をGoogle側に任せられるため
const CONTACT_FORM_EMBED_URL =
  'https://docs.google.com/forms/d/e/1FAIpQLSdhCvJoiN7KLtGFu6ojHkNa6K6RllvkMXTZ5oyBGJGg00MY7w/viewform?embedded=true';
// 高さはフォーム全体が枠内スクロールなしで収まる値（PC幅はGoogleフォームが埋め込みコードで提示した値。
// スマホ幅は文字の折り返しで縦に伸びるため実測で余裕を持たせる）。枠が足りない場合も枠内でスクロールはできる
const CONTACT_FORM_HEIGHT = { xs: 1450, sm: 1129 };

function ContactForm() {
  // iframeが表示できない環境（拡張機能によるブロック等）向けに、同じフォームを別タブで開くリンクを添える
  const plainUrl = CONTACT_FORM_EMBED_URL.replace('?embedded=true', '');
  return (
    <>
      <Box
        component="iframe"
        src={CONTACT_FORM_EMBED_URL}
        title="お問い合わせフォーム"
        sx={{ width: '100%', height: CONTACT_FORM_HEIGHT, border: 0 }}
      />
      <Typography variant="body2" color="text.secondary">
        フォームが表示されない場合は
        <ExternalLink href={plainUrl}>こちら</ExternalLink>
        から開いてください。
      </Typography>
    </>
  );
}

export default function ContactPage() {
  return (
    <StaticPageLayout
      title="お問い合わせ"
      description="investee（investee.info）へのご意見・不具合報告・データの誤りのご指摘の連絡方法を掲載しています。"
      path={siteRoutes.contact}
    >
      <P>
        当サイトへのご意見・ご要望、不具合の報告、データの誤りのご指摘は、下のフォームからお送りください。いただいた内容は確認のうえ、修正や改善に役立てます。個人で運営しているため、個別の返信は行っていません。
      </P>
      <P>
        フォームでは氏名やメールアドレスの入力を求めていません。入力いただいた内容は、確認と改善のためだけに使用します（詳細は
        <InternalLink to={siteRoutes.privacy}>
          プライバシーポリシー
        </InternalLink>
        ）。
      </P>

      <Section title="お問い合わせフォーム">
        <ContactForm />
      </Section>

      <Section title="お問い合わせの際にお願いしたいこと">
        <P>
          データの誤りや表示の不具合をご報告いただく場合は、確認と修正を早く進めるため、次の情報を添えていただけると助かります。
        </P>
        <Bullets>
          <Bullet>企業名または証券コード</Bullet>
          <Bullet>
            カードに表示されている会計期間（例: 2025-04-01 - 2026-03-31）
          </Bullet>
          <Bullet>
            どのグラフ（貸借対照表・損益計算書・キャッシュフロー計算書）の、どの数値が、どう違うか
          </Bullet>
          <Bullet>可能であれば、EDINETの該当する有価証券報告書のページ</Bullet>
        </Bullets>
      </Section>

      <Section title="ご注意">
        <Bullets>
          <Bullet>個別の返信は行っていません。あらかじめご了承ください</Bullet>
          <Bullet>
            個別の銘柄の売買判断や投資に関するご相談にはお答えできません。当サイトは投資助言を行っていません（
            <InternalLink to={siteRoutes.about}>
              このサイトについて
            </InternalLink>
            の免責事項をご覧ください）
          </Bullet>
          <Bullet>
            データの出典や利用上の注意は
            <InternalLink to={siteRoutes.about}>
              このサイトについて
            </InternalLink>
            、Cookie等の取り扱いは
            <InternalLink to={siteRoutes.privacy}>
              プライバシーポリシー
            </InternalLink>
            に記載しています。お問い合わせの前にご一読ください
          </Bullet>
        </Bullets>
      </Section>
    </StaticPageLayout>
  );
}
