import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateTodoInput } from './dto/create-todo.input';

@Injectable()
export class TodoService {
  constructor(private prisma: PrismaService) {}

  findAll() {
    return this.prisma.todo.findMany();
  }

  create(input: CreateTodoInput) {
    const { title, description } = input;
    return this.prisma.todo.create({
      data: { title, description },
    });
  }
}
