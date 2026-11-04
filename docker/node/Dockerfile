FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

CMD ["npm", "run", "dev", "--", "-H", "0.0.0.0"]
