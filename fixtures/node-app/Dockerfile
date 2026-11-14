# Selftest fixture for node-service.yml. Pinless upstream is deliberate here: the fixture is
# built on a hosted runner with Docker Hub reachable, and it is deleted with the run.
FROM docker.io/library/node:24-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY index.js ./

ENV PORT=8080
EXPOSE 8080

CMD ["node", "index.js"]
