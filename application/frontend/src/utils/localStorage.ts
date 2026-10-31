// サイトデータの保存をブロックしたブラウザなどでは、localStorageに触れるだけで例外になる。
// 保存できなくても画面を表示・操作できるよう、例外を呼び出し側に伝えない

export function readLocalStorage(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    // 保存がない場合と同じに扱う
    return null;
  }
}

export function writeLocalStorage(key: string, value: string): void {
  try {
    localStorage.setItem(key, value);
  } catch {
    // 保存しないまま続ける
  }
}
