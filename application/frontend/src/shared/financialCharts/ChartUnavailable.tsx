import React from 'react';

// 「表示不可」は正常系（未対応の会計基準・業種、科目の欠落）。
// エラーバウンダリではなくデータとして描く。noteはバックエンドが形式判定の文脈を
// 知った上で書いた文言なので、そのまま出す。
// サイズをチャートと同じにする理由: カルーセル内でチャートと差し替わるため、
// 高さが違うとスライド切替時にレイアウトが跳ねる
export function ChartUnavailable({
  note,
  width = '90%',
  height = 400,
}: {
  note?: string | null;
  width?: string | number;
  height?: string | number;
}) {
  return (
    <div style={{ width, height, textAlign: 'left' }}>
      {note ?? 'データがない、または表示対応していないデータです。'}
    </div>
  );
}
