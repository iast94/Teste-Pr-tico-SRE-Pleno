# Estágio 1: Builder
FROM node:20-alpine AS builder

WORKDIR /app

# Copia apenas arquivos de dependências para aproveitar o cache de camadas
COPY package.json yarn.lock* ./
RUN yarn install --frozen-lockfile

# Copia o restante do código e gera o build (TypeScript -> JS)
COPY . .
RUN yarn build

# Estágio 2: Runtime (Imagem final otimizada)
FROM node:18-alpine AS runtime

# Definição de variáveis de ambiente exigidas no teste 
ENV APP_ENV=staging
ENV PORT=8080

WORKDIR /app

# Boas práticas de segurança: Criar usuário não-root [cite: 42]
RUN addgroup -g 1001 -S nodejs && \
    adduser -S appuser -u 1001 -G nodejs

# Copia apenas o necessário do estágio builder (redução de tamanho) [cite: 35]
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/node_modules ./node_modules

# Ajusta permissões para o usuário não-root
RUN chown -R appuser:nodejs /app

USER appuser

# Exposição da porta configurável [cite: 31]
EXPOSE ${PORT}

CMD ["node", "dist/main.js"]