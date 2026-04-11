FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm ci --legacy-peer-deps

COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app

COPY --from=builder /app/.medusa/server/package*.json ./
COPY --from=builder /app/.medusa/server/ ./

RUN npm ci --legacy-peer-deps

# Supprimer tout fichier .env qui pourrait écraser les variables Railway
RUN rm -f .env .env.production .env.local

ENV NODE_ENV=production
ENV PORT=9000
EXPOSE 9000

CMD ["sh", "-c", "npx medusa db:migrate; npm run start"]
