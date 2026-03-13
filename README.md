# TODOアプリのリベンジ

### 安定のため、Prismaはバージョン6を使用している

### Dockerを使う
vscode拡張機能のDev Containerを使うことで、コンテナ内でvscodeを使うことができる
そうすることで、PC上とコンテナで環境が異なることがなくなるし、node_modulesをPCで持つ必要がなくなって容量を圧迫しない

### backend,db,adminerはコンテナ化している
cmd+shift+Pから[Dev Containers: Rebuild and Reopen in Container]を選択し、devContainerにより、コンテナ内部でbackendの開発が可能
その際、立ち上げ時はnpx prisma generateが効いていないため、npm run start:devをしてもエラーが出るため、npx prisma generateの実行は必須
