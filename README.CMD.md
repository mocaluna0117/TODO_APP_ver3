# 実行した重要コマンドなど

## gitのセットアップ
git init
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/mocaluna0117/TODO_APP_ver3.git
git push -u origin main

## NestJS プロジェクト作成(backend/ で実行)
npx @nestjs/cli new .　(npmをパッケージマネージャーとして選択)

## GraphQLインストール(backend/ で実行)
npm install @nestjs/graphql @nestjs/apollo graphql apollo-server-express

## Prisma v6 インストール(backend/ で実行)
npm install -D prisma@6(CLIパッケージだから開発時しか使わない)
npm install @prisma/client@6(まさにimportしたりするから、dependenciesに入れる)
## Prisma初期化
npx prisma init

## ExpressとApolloをつなぐパッケージ（@as-integrations/express5）
NestJS + GraphQL (Apollo v4) では内部構造が変わり、@nestjs/graphqlと@apollo/serverだけでなく@as-integrations/express5が必要となった
[Nest] 62124  - 2026/03/13 1:15:21   ERROR [PackageLoader] The "@as-integrations/express5" package is missing. Please, make sure to install it to take advantage of GraphQLModule. というエラーがでてしまう
npm install @as-integrations/express5

npm remove apollo-server-express(NestJSでは不要だった)
npm install @apollo/server
npm install @as-integrations/express5
以下のApollo v4の構成になったため、@as-integrations/express5(Express との接続パッケージ)を入れてエラーを直した
"dependencies": {
  "@apollo/server": "^5.4.0",
  "@nestjs/apollo": "^13.2.4",
  "@nestjs/graphql": "^13.2.4"
}
## NestJS GraphQL (2026) 正しい依存関係
@nestjs/graphql
@nestjs/apollo
@apollo/server
@as-integrations/express5
graphql

## Flutterのインストール
flutter doctor -v を実行して、flutter開発環境が整っているかどうかを確認する
#### zennの記事を参考に、VSCodeの拡張機能からFlutterSDKをインストールした(https://zenn.dev/kra8/articles/6a2f7433304c8b)
daiki.kimura直下にflutterを配置
#### zshrcに以下を追加し、flutterのPATHを通した
export PATH="$PATH:/Users/daiki.kimura/flutter/bin"
#### AppStoreからXCodeをインストール
#### macから元々入っているXCode関連ツールではなく、AppStoreから入れられるXCode版の関連ツール(フルXcode（iOS開発用）)を使用するための設定
xcode-select -p　を実行して、どのツールが使われているか確認(/Library/Developer/CommandLineToolsになっていると、FlutterはiOSビルドできないらしい) 
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
/Applications/Xcode.app/Contents/Developer
になったことをxcode-select -pで確かめる
sudo xcodebuild -runFirstLaunch 
を実行して、ライセンス同意・初回セットアップ・iOS SDK展開をする
#### XCodeのセットアップのためにCocoaPods(iOSライブラリ管理ツール)をインストールする GPTによればHomebrewで入れるのがいいらしい
brew install cocoapods
pod --version でバージョンが出ればOK
#### Andloidの設定は一旦やらない

## flutterでフロントエンド作成(ディレクトリ名はtodo_app)
flutter create todo_app

In order to run your application, type:
  $ cd todo_app
  $ flutter run
Your application code is in todo_app/lib/main.dart.