# Stage 1: Build React app
FROM node:22-slim AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY public/ ./public/
COPY src/ ./src/
COPY tsconfig.json postcss.config.js tailwind.config.js ./

# L'API sera en proxy via nginx, donc on utilise /api
ENV REACT_APP_API_URL=/api
ENV REACT_APP_ANIME_BASE_URL=https://anime-sama.to/

RUN npm run build

# Stage 2: Serve with nginx
FROM nginx:alpine

# Config nginx pour proxy l'API et servir le frontend
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copier le build React
COPY --from=builder /app/build /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
