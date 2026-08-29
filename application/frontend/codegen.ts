import { CodegenConfig } from '@graphql-codegen/cli';

const config: CodegenConfig = {
  // バックエンドがコミットしているSDLファイルを参照する（バックエンド起動なしで型生成できる）。
  // スキーマ変更時はバックエンド側で rake graphql:dump_schema を実行してから型生成する
  schema: '../backend/schema.graphql',
  documents: ['src/**/*.{ts,tsx}'],
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
