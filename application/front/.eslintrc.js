module.exports = {
  env: {
    browser: true,
    es2021: true,
  },
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:react/recommended',
    'prettier',
  ],
  overrides: [
    {
      env: {
        node: true,
      },
      files: ['.eslintrc.{js,cjs}'],
      parserOptions: {
        sourceType: 'script',
      },
    },
  ],
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module',
  },
  plugins: ['@typescript-eslint', 'react'],
  ignorePatterns: ['src/__generated__/**'],
  rules: {
    'no-console': 'warn',
    'no-extra-semi': 'warn',
    'dot-notation': 'warn',
    'prefer-const': 'error',
    'no-unreachable-loop': 'error',
    'no-var': 'error',
    // 「if () return;」のような記述は「{}」つきの記述とする
    curly: 'error',
    // 「(obj?.foo)();」->「(obj?.foo)?.();」
    'no-unsafe-optional-chaining': 'error',
  },
};
