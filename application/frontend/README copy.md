# 参考
## react で eslint と prettier を使用する
eslintインストール
```
% yarn add -D eslint
```
eslint初期化・設定ファイル作成
```
% yarn run eslint --init
yarn run v1.22.19
$ /Users/shin4488/MyContents/development/github/financial-statement/application/front/node_modules/.bin/eslint --init
You can also run this command directly using 'npm init @eslint/config'.
Need to install the following packages:
  @eslint/create-config
Ok to proceed? (y) y
✔ How would you like to use ESLint? · problems
✔ What type of modules does your project use? · esm
✔ Which framework does your project use? · react
✔ Does your project use TypeScript? · No / Yes
✔ Where does your code run? · browser
✔ What format do you want your config file to be in? · JavaScript
The config that you've selected requires the following dependencies:

@typescript-eslint/eslint-plugin@latest eslint-plugin-react@latest @typescript-eslint/parser@latest
✔ Would you like to install them now? · No / Yes
✔ Which package manager do you want to use? · yarn
```
prettierインストール
```
% yarn add -D eslint-config-prettier prettier
```
prettier設定ファイル作成
```
% touch .prettierrc
```
```js:./.prettierrc
{
  "trailingComma": "all",
  "tabWidth": 2,
  "semi": true,
  "singleQuote": true
}
```
保存時に自動でeslintとprettierを適用（.vscode/setting.jsonの編集）
```json
{
  // 保存時のprettier自動フォーマッターを有効化
  "editor.formatOnSave": true,
  // prettierをデフォルトのフォーマッタに設定
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  // 保存時のeslintを有効化
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  // markdownは保存時にprettierを適用しない
  "[markdown]": {
    "editor.formatOnSave": false
  }
}
```

## TypeScriptとeslintでエイリアス追加
https://qiita.com/Statham/items/8a1161c7816e360590f3
TypeScriptのエイリアス設定
```json:tsconfig.json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```
eslint側でエイリアス設定
トランスパイル後のjsファイルでもエイリアスを解決させるために行う
```
% yarn -D eslint-import-resolver-typescript
```
```js:.eslintrc.js
module.exports = {
  settings: {
    'import/resolver': {
      node: {
        extensions: ['.js', '.jsx', '.json', '.ts', '.tsx'],
      },
      typescript: {},
    },
  },
}
```
## react-router-domによるルーティング
https://www.webopixel.net/javascript/1773.html
https://zenn.dev/monicle/articles/react-router-v6-suspense-idiom

## rechartsでwater flow 棒グラフを作成する
https://medium.com/2359media/tutorial-how-to-create-a-waterfall-chart-in-recharts-15a0e980d4b

## ReactでVueのslotのような使い方をする
propsのデータとして`children: JSX.Element | JSX.Element[];`を使う。

# Getting Started with Create React App

This project was bootstrapped with [Create React App](https://github.com/facebook/create-react-app).

## Available Scripts

In the project directory, you can run:

### `yarn start`

Runs the app in the development mode.\
Open [http://localhost:3000](http://localhost:3000) to view it in the browser.

The page will reload if you make edits.\
You will also see any lint errors in the console.

### `yarn test`

Launches the test runner in the interactive watch mode.\
See the section about [running tests](https://facebook.github.io/create-react-app/docs/running-tests) for more information.

### `yarn build`

Builds the app for production to the `build` folder.\
It correctly bundles React in production mode and optimizes the build for the best performance.

The build is minified and the filenames include the hashes.\
Your app is ready to be deployed!

See the section about [deployment](https://facebook.github.io/create-react-app/docs/deployment) for more information.

### `yarn eject`

**Note: this is a one-way operation. Once you `eject`, you can’t go back!**

If you aren’t satisfied with the build tool and configuration choices, you can `eject` at any time. This command will remove the single build dependency from your project.

Instead, it will copy all the configuration files and the transitive dependencies (webpack, Babel, ESLint, etc) right into your project so you have full control over them. All of the commands except `eject` will still work, but they will point to the copied scripts so you can tweak them. At this point you’re on your own.

You don’t have to ever use `eject`. The curated feature set is suitable for small and middle deployments, and you shouldn’t feel obligated to use this feature. However we understand that this tool wouldn’t be useful if you couldn’t customize it when you are ready for it.

## Learn More

You can learn more in the [Create React App documentation](https://facebook.github.io/create-react-app/docs/getting-started).

To learn React, check out the [React documentation](https://reactjs.org/).

# Redux
構成
https://zenn.dev/engstt/articles/293e7420c93a18

classコンポーネントでのフックの使用→connectの使用
https://stackoverflow.com/questions/57135857/how-can-i-use-react-redux-useselector-in-class-component
https://react.dev/warnings/invalid-hook-call-warning のエラーが発生するため、対処が必要。

connectをTypeScritptで使用する
https://qiita.com/NeGI1009/items/382b54106a79944652a3

## 検索
企業検索: https://mui.com/material-ui/react-autocomplete/#limit-tags
業界選択: YouTubeのイメージ
https://mui.com/material-ui/react-chip/#chip-array
https://mui.com/material-ui/react-chip/#color-chip
https://mui.com/material-ui/react-chip/#clickable
CFタイプ選択: Select, MenuItem

## Chip付きの複数入力
https://stackoverflow.com/questions/75598135/chip-inside-a-material-textfield-with-multilines
検索アイコンを出しつつ、Chipも表示したい時↓
https://stackoverflow.com/questions/72854517/applying-inputadornment-to-mui-autocomplete-removes-the-options-list

## react-infinite-scrollerライブリのInfiniteScrollのpageをリセットする
https://github.com/danbovey/react-infinite-scroller/issues/12#issuecomment-339375017
