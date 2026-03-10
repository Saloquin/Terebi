FROM node:22-slim

WORKDIR /app

# Copier les fichiers de dépendances
COPY package.json package-lock.json ./

# Installer les dépendances (sans puppeteer, on utilise FlareSolverr)
RUN npm ci --omit=dev && npm install typescript ts-node

# Copier le code source
COPY tsconfig.json ./
COPY src/ ./src/

# Port de l'API
EXPOSE 3001

# Lancer en mode production compilé
RUN npx tsc

CMD ["node", "dist/index.js"]
