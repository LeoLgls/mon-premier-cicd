# Dockerfile — Application Calculator API
# ═══ STAGE 1 : BUILD & TEST ════════════════════════
FROM node:18-alpine AS builder

WORKDIR /app

# Copier les fichiers de dépendances EN PREMIER (optimisation cache)
COPY package*.json ./

# Installer TOUTES les dépendances (dev + prod pour les tests)
RUN HUSKY=0 npm ci

# Copier le code source
COPY . .

# Exécuter les tests — le build échoue si les tests échouent
RUN npm test

# ═══ STAGE 2 : RUNTIME ═════════════════════════════
FROM node:18-alpine AS runtime

WORKDIR /app

COPY --from=builder /app/package*.json ./
COPY --from=builder /app/src ./src

ENV NODE_ENV=production

# Supprimer le script prepare (husky) avant d'installer
RUN npm pkg delete scripts.prepare && npm ci --omit=dev

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD [ "node", "src/server.js" ]