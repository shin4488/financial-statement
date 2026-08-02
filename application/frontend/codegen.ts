import { CodegenConfig } from '@graphql-codegen/cli';

const config: CodegenConfig = {
  // コンテナ内でリクエストを送るため、コンテナ名・内部的なポート指定とする。webコンテナは内部的に80ポートでリクエストを受け付ける
  schema: 'http://web/api/graphql',
  documents: ['src/**/*.tsx'],
  generates: {
    './src/__generated__/': {
      preset: 'client',
      plugins: [],
      presetConfig: {
        gqlTagName: 'gql',
      },
      config: {
        scalars: {
          // MoneyスカラはJSON数値のまま届く（バックエンドのTypes::MoneyType参照）
          Money: 'number',
        },
      },
    },
  },
  ignoreNoDocuments: true,
};

export default config;
