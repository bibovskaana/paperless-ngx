#!/bin/sh
set -e

echo "Running database migrations..."
python3 manage.py migrate --noinput

echo "Starting Granian..."
exec granian --interface wsgi paperless.wsgi:application --host 0.0.0.0 --port 8000

