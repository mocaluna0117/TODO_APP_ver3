import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { Module } from '@nestjs/common';
import { GraphQLModule } from '@nestjs/graphql';
import { join } from 'path';
import { PrismaModule } from './prisma/prisma.module';
import { TodoModule } from './todo/todo.module';

@Module({
  imports: [
    // GraphQLModuleはGraphQLサーバーを立てる役割で、NestJSでGraphQLを使うためのモジュール
    // forRootはGraphQLModuleをアプリ全体で使うという意味、NestJSではよくこの書き方をする
    GraphQLModule.forRoot<ApolloDriverConfig>({
      driver: ApolloDriver, // GraphQLエンジンに Apollo を使う
      // GraphQLのschemaを自動生成する(Code First（NestJS推奨）)
      autoSchemaFile: join(process.cwd(), 'src/schema.gql'),
    }),
    PrismaModule,
    TodoModule,
  ],
})
export class AppModule {}

/* 
Todo.model.ts
Resolver.ts
Input.ts
      ↓
GraphQLModule
      ↓
autoSchemaFile
      ↓
schema.gql 自動生成
      ↓
Apollo Server
      ↓
http://localhost:3050/graphql
*/
