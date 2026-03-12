FROM node:20-alpine

WORKDIR /todo_app

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 3000

# 謎のエラーが消える
CMD ["sleep", "infinity"]