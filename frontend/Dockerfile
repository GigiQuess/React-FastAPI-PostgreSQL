FROM node:20.18
WORKDIR /workspace/frontend

# 依存だけ先にコピーしてキャッシュ効率を上げる
COPY package*.json ./
RUN npm ci --silent --no-audit --progress=false

COPY . .

CMD ["npm", "run", "dev", "--", "--host"]
