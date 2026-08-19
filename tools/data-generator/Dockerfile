FROM node:22-alpine

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --omit=dev

COPY src ./src
COPY profiles ./profiles

ENTRYPOINT ["node", "src/index.mjs"]
