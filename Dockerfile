# Estágio 1: Builder
FROM node:20-alpine AS builder

WORKDIR /app

# Copia apenas arquivos de dependências para aproveitar o cache de camadas
COPY package.json yarn.lock* ./

# Força o Yarn a instalar apenas as dependências listadas em package.json e as versões exatas listadas no yarn.lock
RUN yarn install --frozen-lockfile --production

# Estágio 2: Runtime (Imagem final otimizada)
FROM node:20-alpine AS runtime

# Identifica quem é o responsável pela imagem
LABEL maintainer="iast94 - SRE Team"

# Definição de variáveis de ambiente
ENV APP_ENV=staging
ENV PORT=8080

WORKDIR /app

# Segurança: Usuário non-root com ID fixo para conformidade com K8s / Criação de usuário e grupo ANTES dos COPYs (Otimização de Cache)
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Copia apenas o necessário do estágio builder, COPY com --chown numérico (Melhor Prática de Segurança e Tamanho)
COPY --from=builder --chown=1001:1001 /app/node_modules ./node_modules
COPY --chown=1001:1001 package.json ./
COPY --chown=1001:1001 src/ ./src/

# USER numérico para compatibilidade total
USER appuser

# Exposição da porta configurável
EXPOSE ${PORT}

# Executa a aplicação a partir da pasta src
CMD ["node", "src/app.js"]