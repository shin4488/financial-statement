import { colorByRole, colorForRole, hiddenRoles } from './colorRoles';

// console.warnを黙らせて呼び出し回数だけ数える。jest/vitestどちらのランナーでも動くよう、
// ランナー固有のspy(jest.spyOn / vi.spyOn)は使わない
/* eslint-disable no-console */
const captureWarn = () => {
  const original = console.warn;
  let count = 0;
  console.warn = () => {
    count += 1;
  };
  return {
    count: () => count,
    restore: () => {
      console.warn = original;
    },
  };
};
/* eslint-enable no-console */

describe('colorForRole', () => {
  it('定義済みroleはその色を返す', () => {
    expect(colorForRole('equity')).toBe(colorByRole.equity);
  });

  it('未知のroleはグレーにフォールバックし、roleごとに1回だけ警告する', () => {
    const warn = captureWarn();
    const first = colorForRole('unknownRole');
    const second = colorForRole('unknownRole');
    expect(first).toBe(second);
    expect(first).not.toBe('');
    expect(warn.count()).toBe(1);
    warn.restore();
  });

  it('Object.prototype由来の名前（constructor等）でもプロトタイプの値を返さない', () => {
    const warn = captureWarn();
    expect(typeof colorForRole('constructor')).toBe('string');
    expect(colorForRole('constructor')).toMatch(/^#/);
    warn.restore();
  });
});

describe('hiddenRoles', () => {
  it('詰め物のspacerはツールチップ非表示のroleとして定義されている', () => {
    expect(hiddenRoles.has('spacer')).toBe(true);
  });
});

describe('colorByRole', () => {
  it('ウォーターフォールの増減role（cashIncrease / cashDecrease）も同じマップで管理する', () => {
    expect(colorByRole.cashIncrease).toMatch(/^#/);
    expect(colorByRole.cashDecrease).toMatch(/^#/);
  });
});
