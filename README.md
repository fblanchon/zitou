# zitou

Le site zitou.fr : un projet Symfony 8.1 autonome, sans moteur.

- Page d'accueil : `src/Controller/HomeController.php` et `templates/home/index.html.twig`, textes dans `translations/messages.fr.yaml` (`site.home.*`).
- Styles, script, polices et images de la page : `public/accueil/`. Crédits des images (Pexels) : `public/accueil/images/CREDITS.md`.
- Lancer en local : `composer install`, puis `make serve` (ou `symfony serve -d`).
- Tests : `php bin/phpunit`.
- Déployer : `make deploy` (pousse, puis lance `bin/deploy.sh` sur le serveur).
