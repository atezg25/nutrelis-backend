#!/bin/sh
set -e

echo "=== DATABASE URL CHECK ==="
echo $DATABASE_URL | cut -c1-30

echo "=== RUNNING MIGRATIONS ==="
node_modules/.bin/medusa db:migrate

echo "=== MIGRATIONS DONE - STARTING SERVER ==="
node_modules/.bin/medusa start
