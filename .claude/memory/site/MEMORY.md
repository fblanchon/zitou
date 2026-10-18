# Mémoire du site : index

Décisions et particularités propres à ce site, versionnées dans son dépôt. La mémoire du moteur (`zitou-client/`, `zitou-shared/`) vient de `vendor/` et ne se modifie pas ici.

- zitou.fr, tiré du modèle zitou-client le 17/10/2026 (étape 5) en transformant sur place l'ancien projet Symfony 8.1 : historique, clé de déploiement, dossier `/var/www/zitou` et base gardés. Les exemples du modèle (sous-titre des publications, thème `exemple`, page `/effets`) ne sont pas repris.
- Thème `zitou` dans `templates/Frontend/themes/zitou/` ; la page d'accueil est une publication choisie dans Contenus.
- Production : `Makefile.local` (VPS `monvps`, `/var/www/zitou`, worker `zitou-worker-zitou`) ; première version `v1.0.0` par la variable de dépôt `FIRST_VERSION`. `make deploy` lance `make deploy-latest` sur le serveur (l'ancien `bin/deploy.sh` a disparu).
