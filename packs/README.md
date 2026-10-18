# Packs de démo

Un dossier par pack (ou une archive `.zip`), déposé ici pour être chargé en local :

- `make demo-pack PACK=<nom>` charge le pack dans la base de développement, si elle n'a encore aucune publication ;
- `make pack-serve PACK=<nom>` le sert dans une base à part, sur <http://<nom>.localhost:8100>, puis `make pack-user PACK=<nom>` crée un compte et `make pack-stop PACK=<nom>` arrête le serveur.

Le contenu de ce dossier n'est pas versionné : un pack appartient au client qui l'a préparé. Le format est décrit dans `vendor/fblanchon/zitou-core/docs/zitou-client/packs-de-demo.md`, avec le pack `exemple` du moteur pour modèle (`make demo-pack PACK=exemple`).
