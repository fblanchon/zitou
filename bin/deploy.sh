#!/usr/bin/env bash
set -euo pipefail
cd /var/www/zitou
git pull --ff-only
composer install --no-dev --optimize-autoloader --no-interaction
php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration
php bin/console asset-map:compile
php bin/console cache:clear
echo "Déployé : $(git log -1 --oneline)"

