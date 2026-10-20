FROM ubuntu:24.04 AS base
# Ubuntu 24.04: misma base para la que Bambu publica el AppImage de OrcaSlicer (evita problemas de glibc/libstdc++).
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates gnupg xz-utils libfuse2 file \
  && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && apt-get install -y --no-install-recommends \
    libgl1 libglu1-mesa libegl1 libgtk-3-0t64 libwebkit2gtk-4.1-0 libxkbcommon0 libnss3 libatk-bridge2.0-0 libgbm1 libasound2t64 fonts-liberation libmspack0 \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# pnpm viene de corepack, fijado por versión y sha512 en "packageManager" de package.json.
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
RUN corepack enable
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .
RUN pnpm run build
# Chromium genera los PDF; si no se instala el contenedor no arranca sin avisar: la salud del sistema (Configuración) lo informa.
RUN pnpm exec playwright install chromium --with-deps
# OrcaSlicer (laminador del servidor). Se extrae el AppImage; no necesita FUSE ni pantalla.
RUN bash scripts/install-orca.sh || echo "OrcaSlicer no se pudo instalar: el laminador del servidor quedará deshabilitado"
ENV NODE_ENV=production STORAGE_DIR=/data/storage DATA_DIR=/data PGLITE_DIR=/data/pgdata
VOLUME /data
EXPOSE 3000
CMD ["sh", "-c", "pnpm exec tsx scripts/seed.ts --bootstrap-only && pnpm exec next start -p 3000"]
