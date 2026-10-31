// 描く順番を待っている処理
const waiting: (() => void)[] = [];
let drawing = false;

function drawNext() {
  const draw = waiting.shift();
  if (!draw) {
    drawing = false;
    return;
  }
  draw();
  // 描いた要素に続く更新を画面に出してから、次の要素を描く
  requestAnimationFrame(() => setTimeout(drawNext));
}

// 見えていない要素を描く処理を、順番待ちに加える。多くの要素を一度に描くと、その間は画面が止まるため、
// 加えた順に1フレームに1つずつ描く。返す関数を呼ぶと、順番待ちから外れる
export function waitForTurn(draw: () => void) {
  waiting.push(draw);
  if (!drawing) {
    drawing = true;
    setTimeout(drawNext);
  }
  return () => {
    const index = waiting.indexOf(draw);
    if (index >= 0) {
      waiting.splice(index, 1);
    }
  };
}
