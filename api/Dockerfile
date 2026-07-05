FROM node:22-slim

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src/ ./src/

RUN npm run build && npm prune --omit=dev

EXPOSE 3001

CMD ["node", "dist/index.js"]
