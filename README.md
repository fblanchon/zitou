# zitou

Le site [zitou.fr](https://zitou.fr), construit sur le moteur [zitou-core](https://github.com/fblanchon/zitou-core) à partir du modèle zitou-client.

<!-- zitou:common:start -->
## Démarrer

Prérequis sur le PC (WSL) : PHP 8.4 (avec `pgsql`, `intl`, `gd`, `sodium`), Composer, Node 24 avec pnpm, PostgreSQL 16, et le moteur cloné à côté du site (`../zitou-core`) tant que le site le requiert en dépôt local.

```bash
make setup-env     # .env.local avec un secret neuf ; relire DATABASE_URL
make install-dev   # première fois seulement : dépendances, base recréée, démo, build
php bin/console zitou:user:create --dev   # premier compte, rôle développeur
make start-d       # serveur Symfony, admin sur /suite
make worker        # tâches de fond : e-mails, webhooks, publication programmée, purges de nuit
```

## Au quotidien

```bash
make pull-update   # après un git pull : dépendances, migrations, synchronisations, build (données gardées)
make zitou-update  # monter le moteur, puis les mêmes étapes ; lire ensuite « Dans zitou-client » de son CHANGELOG
make dev           # serveur Vite pour travailler sur le front
make ft            # avant chaque commit : style, analyse, schéma, build, tests
make demo          # contenus de démonstration des modules, par-dessus la base (jamais en production)
make pack-serve PACK=exemple   # un site de démonstration complet, servi à part sur http://exemple.localhost:8100
make help          # toutes les commandes
```

Après un `git pull` qui amène aussi une montée du moteur : `make pull-zitou-update`, dans cet ordre.

## Production

Le site se déploie sur un tag, jamais sur une branche : chaque fusion dans `main` publie une version (workflow « Release »). Sur le serveur, `make install-prod` la première fois, puis `make deploy-latest` (ou `make deploy` depuis le PC, réglé dans `Makefile.local`). `make deploy-check` vérifie le site en lecture seule. Le détail est dans `vendor/fblanchon/zitou-core/docs/zitou-client/deploiement.md`.

## À savoir

- Le moteur arrive dans `vendor/fblanchon/zitou-core/` : on n'y touche jamais. Le site étend, surcharge au même chemin ou remplace par les cinq couches.
- `Makefile`, `config/packages/security.yaml`, `jsconfig.json`, la partie commune de ce README et les liens `CLAUDE.md` et `.claude/` viennent du moteur et sont refaits par `make sync`. Les réglages et commandes du site vont dans `Makefile.local`, ses règles de sécurité dans `config/packages/security_site.yaml`, ses variables sous la ligne de séparation de `.env`.
- `public/build` est un lien versionné vers les fichiers compilés du moteur.
- Les secrets (clés de l'anti-robot `ZITOU_CAPTCHA_*`, mots de passe) vont dans `.env.local`, jamais dans `.env`.
- La mémoire Claude propre au site est dans `.claude/memory/site/`.
<!-- zitou:common:end -->

## Spécifique à ce projet

- Thème : `templates/Frontend/themes/zitou/`, à créer puis activer dans Configuration › Thèmes avec l'identifiant `zitou`. La page d'accueil est une publication choisie dans Contenus.
- Production : le site vit dans `/var/www/zitou` sur le VPS (`monvps`) ; `make deploy` depuis le PC lance `make deploy-latest` sur le serveur. Le worker tourne sous le service systemd `zitou-worker-zitou` (réglages dans `Makefile.local`).
- Première version sur le moteur : `v1.0.0` (variable de dépôt `FIRST_VERSION`).
