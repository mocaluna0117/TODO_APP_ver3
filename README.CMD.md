# 実行した重要コマンドなど

### gitのセットアップ
git init
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/mocaluna0117/TODO_APP_ver3.git
git push -u origin main

### NestJS プロジェクト作成(backend/ で実行)
npx @nestjs/cli new .　(npmをパッケージマネージャーとして選択)

### GraphQLインストール(backend/ で実行)
npm install @nestjs/graphql @nestjs/apollo graphql apollo-server-express

### Prisma v6 インストール(backend/ で実行)
npm install -D prisma@6(CLIパッケージだから開発時しか使わない)
npm install @prisma/client@6(まさにimportしたりするから、dependenciesに入れる)
### Prisma初期化
npx prisma init