# Mémoire du site : index

Décisions et particularités propres à ce site, versionnées dans son dépôt. La mémoire du moteur (`zitou-client/`, `zitou-shared/`) vient de `vendor/` et ne se modifie pas ici.

- zitou.fr, tiré du modèle zitou-client le 17/10/2026 (étape 5) en transformant sur place l'ancien projet Symfony 8.1 : historique, clé de déploiement, dossier `/var/www/zitou` et base gardés. Les exemples du modèle (sous-titre des publications, thème `exemple`, page `/effets`) ne sont pas repris.
- Thème `zitou` dans `templates/Frontend/themes/zitou/`. La page d'accueil joyeuse (bonjour selon l'heure, confettis, « le petit bonheur du jour » avec polaroïd) est son `home.html.twig`, affichée tant qu'aucune publication n'est choisie comme accueil dans Contenus ; textes sous `site.home.*` dans `translations/messages.fr.yaml`. Ses fichiers sont hors du build du moteur, dans `public/accueil/` (CSS et JS limités à `.zitou-home`, polices auto-hébergées car la CSP bloque Google Fonts, images Pexels et leurs crédits dans `public/accueil/images/CREDITS.md`). Test : `tests/Functional/JoyfulHomePageTest.php`.
- Production : `Makefile.local` (VPS `monvps`, `/var/www/zitou`, worker `zitou-worker-zitou`) ; première version `v1.0.0` par la variable de dépôt `FIRST_VERSION` = `1.0.0` (sans « v »). `make deploy` lance `make deploy-latest` sur le serveur (l'ancien `bin/deploy.sh` a disparu).
