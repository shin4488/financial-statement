import { colorByRole, colorForRole, hiddenRoles } from './colorRoles';

describe('colorForRole', () => {
  it('定義済みroleはその色を返す', () => {
    expect(colorForRole('equity')).toBe(colorByRole.equity);
  });

  it('未知のroleはグレーにフォールバックし、roleごとに1回だけ警告する', () => {
    const warn = jest
      .spyOn(console, 'warn')
      .mockImplementation(() => undefined);
    const first = colorForRole('unknownRole');
    const second = colorForRole('unknownRole');
    expect(first).toBe(second);
    expect(first).not.toBe('');
    expect(warn).toHaveBeenCalledTimes(1);
    warn.mockRestore();
  });

  it('Object.prototype由来の名前（constructor等）でもプロトタイプの値を返さない', () => {
    const warn = jest
      .spyOn(console, 'warn')
      .mockImplementation(() => undefined);
    expect(typeof colorForRole('constructor')).toBe('string');
    expect(colorForRole('constructor')).toMatch(/^#/);
    warn.mockRestore();
  });
});

describe('hiddenRoles', () => {
  it('詰め物のspacerはツールチップ非表示のroleとして定義されている', () => {
    expect(hiddenRoles.has('spacer')).toBe(true);
  });
});
