FROM node:18

WORKDIR /workspace/frontend

COPY frontend/package*.json ./
RUN npm install

COPY frontend /workspace/frontend

CMD ["npm", "run", "dev", "--", "--host"]
