import {
  maxStockCodes,
  parseCashFlowType,
  parseStockCodes,
} from './searchCriteria';

const params = (query: string) => new URLSearchParams(query);

describe('parseStockCodes', () => {
  it('小文字・空白混じりの入力を大文字・trim済みに正規化する（DBの保存形式に合わせる）', () => {
    expect(parseStockCodes(params('stock-codes=391a, 7203 ,,'))).toEqual([
      '391A',
      '7203',
    ]);
  });

  it('大文字・小文字や空白だけ違うコードは、最初に出た位置で1つにまとめる', () => {
    expect(
      parseStockCodes(params('stock-codes=7203,604A,604a, 604A ,7203')),
    ).toEqual(['7203', '604A']);
  });

  it('指定がなければ空配列', () => {
    expect(parseStockCodes(params(''))).toEqual([]);
  });

  it('件数はサーバ側バリデーションと同じ上限で切り詰める', () => {
    const many = Array.from({ length: maxStockCodes + 10 }, (_, i) => `${i}`);
    expect(
      parseStockCodes(params(`stock-codes=${many.join(',')}`)),
    ).toHaveLength(maxStockCodes);
  });

  it('上限は重複をまとめた後のコードの数で数える', () => {
    const duplicated = Array.from({ length: maxStockCodes }, () => '7203');
    expect(
      parseStockCodes(
        params(`stock-codes=${[...duplicated, '604A'].join(',')}`),
      ),
    ).toEqual(['7203', '604A']);
  });
});

describe('parseCashFlowType', () => {
  it('定義済みの値はそのまま返す', () => {
    expect(parseCashFlowType(params('cash-flow-type=healthy'))).toBe('healthy');
  });

  it('未指定・未知の値・prototype由来の名前はnoneに落とす', () => {
    expect(parseCashFlowType(params(''))).toBe('none');
    expect(parseCashFlowType(params('cash-flow-type=bogus'))).toBe('none');
    expect(parseCashFlowType(params('cash-flow-type=constructor'))).toBe(
      'none',
    );
  });
});
