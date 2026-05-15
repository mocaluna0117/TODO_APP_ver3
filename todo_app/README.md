# todo_app

## flutterのセットアップ

## Getting Started
[online documentation](https://docs.flutter.dev/)
flutter run を実行する
## Flutterの開発スタイル
lib/ ← ここが本体（99%ここ）
ios/ android/ ← 必要なときだけ触る

UI作る
ロジック書く
API通信
状態管理
👉 全部 lib/ に書く

## Vite/Nodeのpackage.jsonとFlutterの対応関係
|Flutter|Vite/Node|
|----|----|
|pubspec.yaml|package.json|
|dependencies|dependencies|
|dev_dependencies|devDependencies|

package-lock.json === pubspec.lock といえる

|Flutter/Dart|Node|
|----|----|
|analysis_options.yaml|.eslintrc|
|flutter_lints|eslint-config
## .dart_tool ディレクトリの役割
FlutterやDartが裏で使う作業フォルダで人間は基本触らない
1. pubspec.yamlを元にどのパッケージを使うかどこにあるか その情報をキャッシュしている
2. アプリをビルドするときの中間ファイル・設定情報
3. Flutter / Dartのツールが高速化のために使う
4. .gitignoreに入れる
## .ideaの役割
.vscode/みたいなもので、IDE（エディタ）の設定フォルダ　つまりアプリの動作には無関係
## android,ios,linux,macos,web,windowディレクトリはすべて同じレイヤーであるから、リリースしたいプラットフォームのディレクトリのみ意識したら良い
|ディレクトリ|中身|
|----|----|
|android|Kotlin/Java|
|ios|Swift/Objective-C|
|web|JS/HTML|
|macos|macOSアプリ|
|windows|Windowsアプリ|
|linux|Linuxアプリ|
## lib は