## 全体アーキテクチャ
Flutter(iOSアプリ)----(GraphQL)----▶︎NestJS(API)----▶︎Prisma(ver6)----▶︎PostgreSQL

DockerでNestJSとPostgresQLを動かし、
flutterはローカルPCで動かす

## プロジェクト構成
todo-app
　　 ├── flutter_app 
　　 │
　　 ├── backend
　　 │   ├── src
　　 │   ├── prisma ← ver6
　　 │   └── Dockerfile
　　 │
　　 └── docker-compose.yml