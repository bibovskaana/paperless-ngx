# Stage 1: frontend-builder
FROM node:22-slim AS frontend-builder
COPY src-ui /src/src-ui
WORKDIR /src/src-ui
RUN corepack enable && pnpm install
RUN ./node_modules/.bin/ng build --configuration production

# Stage 2: backend-builder
FROM python:3.12-slim AS backend-builder
WORKDIR /usr/src/paperless/src

RUN pip install --no-cache-dir uv
RUN apt-get update && apt-get install -y --no-install-recommends build-essential libmagic1 \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml uv.lock ./

RUN uv export --no-dev --extra postgres --extra webserver --format requirements-txt --output-file requirements.txt \
    && uv pip install --system --no-cache \
       --index https://pypi.org/simple \
       --index https://download.pytorch.org/whl/cpu \
       --index-strategy unsafe-best-match \
       -r requirements.txt

COPY src/ ./
COPY --from=frontend-builder /src/src/documents/static/frontend ./documents/static/frontend
RUN PAPERLESS_SECRET_KEY=dummy python3 manage.py collectstatic --noinput --clear

# Stage 3: runtime 
FROM python:3.12-slim AS runtime
WORKDIR /usr/src/paperless/src

RUN apt-get update && apt-get install -y --no-install-recommends \
    tesseract-ocr tesseract-ocr-eng \
    qpdf ghostscript unpaper poppler-utils \
    postgresql-client imagemagick gettext curl libmagic1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=backend-builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=backend-builder /usr/local/bin /usr/local/bin
COPY --from=backend-builder /usr/src/paperless/static /usr/src/paperless/static
COPY --from=backend-builder /usr/src/paperless/src ./
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000
ENTRYPOINT ["/entrypoint.sh"]