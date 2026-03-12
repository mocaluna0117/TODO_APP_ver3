import { Args, Mutation, Query, Resolver } from '@nestjs/graphql';
import { CreateTodoInput } from './dto/create-todo.input';
import { Todo } from './todo.entity';
import { TodoService } from './todo.service';

@Resolver(() => Todo)
export class TodoResolver {
  constructor(private todoService: TodoService) {}

  @Query(() => [Todo])
  todos() {
    return this.todoService.findAll();
  }

  @Mutation(() => Todo)
  createTodo(@Args('createTodoInput') createTodoInput: CreateTodoInput) {
    return this.todoService.create(createTodoInput);
  }
}
