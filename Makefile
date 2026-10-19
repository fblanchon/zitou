# Site commands, copied from zitou-core (.claude/client_template/Makefile) by "make sync-makefile".
# Do not edit here: site settings and site commands belong in Makefile.local, which is never overwritten.

.DEFAULT_GOAL := help
-include Makefile.local

CONSOLE := php bin/console
ENGINE_DIR := vendor/fblanchon/zitou-core
KIT_DIR := $(ENGINE_DIR)/.claude/client_template
SYNC := php $(ENGINE_DIR)/bin/sync-client
TOOLS := php-cs-fixer phpstan rector twig-cs-fixer
# Quality settings: the site's own file when it has one, otherwise the engine's default for sites.
PHPSTAN_CONFIG := $(firstword $(wildcard phpstan.dist.neon) $(KIT_DIR)/quality/phpstan.dist.neon)
RECTOR_CONFIG := $(firstword $(wildcard rector.php) $(KIT_DIR)/quality/rector.php)
CS_CONFIG := $(firstword $(wildcard .php-cs-fixer.dist.php) $(KIT_DIR)/quality/php-cs-fixer.dist.php)
# A "make zitou-update" younger than this keeps "make pull-update" from going back to the previous engine.
ENGINE_UPDATE_MARKER := var/zitou/engine-updated-at

# Production settings, overridden in Makefile.local (fiche 36).
DEPLOY_HOST ?=
DEPLOY_PATH ?=
WORKER_SERVICE ?=
PHP_FPM_SERVICE ?=
# Port of a demo pack served beside the development site (make pack-serve).
PACK_PORT ?= 8100

## —— Démarrer ——
setup-env: ## Crée .env.local avec un secret d'application et une clé de chiffrement neufs (ne touche pas à un .env.local existant)
	@if [ -f .env.local ]; then \
		echo ".env.local existe déjà : rien à faire."; \
		grep -qs '^ZITOU_ENCRYPTION_KEY=.' .env.local || echo "Il n'a pas de clé de chiffrement : php bin/console zitou:encryption:key en donne une à y ajouter."; \
		exit 0; \
	fi; \
	secret=$$(php -r 'echo bin2hex(random_bytes(16));'); \
	key=$$(php -r 'echo base64_encode(random_bytes(32));'); \
	printf '%s\n' "# Settings of this machine, never committed. Production secrets go here too." "APP_SECRET=$$secret" "# Key of the encrypted settings: keep it in the password manager, losing it loses them." "ZITOU_ENCRYPTION_KEY=$$key" "# DATABASE_URL=\"postgresql://app:app@127.0.0.1:5432/<base>?serverVersion=16&charset=utf8\"" > .env.local; \
	echo ".env.local créé : relire DATABASE_URL dans .env et, si besoin, la redéfinir ici. Garder ZITOU_ENCRYPTION_KEY dans le gestionnaire de mots de passe."

install: ## Installe le site, les dépendances internes du moteur et ses outils de qualité
	composer install
	$(MAKE) engine-deps engine-tools
	$(MAKE) check-build-link

install-dev: ## Première installation sur le PC : dépendances, base supprimée puis recréée, démo, build (jamais en production)
	@$(MAKE) --no-print-directory refuse-prod
	$(MAKE) install
	$(MAKE) db-reset
	$(MAKE) demo
	$(MAKE) build
	@echo "Créer le premier compte : $(CONSOLE) zitou:user:create --dev"

# With the engine linked to ../zitou-core, its own development dependencies stay: it is worked on too.
ENGINE_LINKED := $(shell test -L $(ENGINE_DIR) && echo yes)

engine-deps: ## Installe ce dont le build du moteur a besoin (son vendor/ et ses paquets JavaScript)
	composer install --working-dir=$(ENGINE_DIR) $(if $(ENGINE_LINKED),,--no-dev) --no-scripts --no-interaction
	cd $(ENGINE_DIR) && pnpm install --frozen-lockfile

engine-tools: ## Installe les outils de qualité du moteur, chacun dans son dossier (développement seulement)
	@for tool in $(TOOLS); do composer install --working-dir=$(ENGINE_DIR)/tools/$$tool --no-interaction --no-progress; done

build: translations ## Construit le front du moteur et du site (ZITOU_CLIENT_DIR = ce dossier)
	@test -f $(ENGINE_DIR)/vendor/autoload.php -a -d $(ENGINE_DIR)/node_modules || $(MAKE) --no-print-directory engine-deps
	cd $(ENGINE_DIR) && ZITOU_CLIENT_DIR=$(CURDIR) pnpm build
	$(MAKE) check-build-link

dev: translations ## Lance le serveur Vite du moteur avec les fichiers du site
	@test -f $(ENGINE_DIR)/vendor/autoload.php -a -d $(ENGINE_DIR)/node_modules || $(MAKE) --no-print-directory engine-deps
	cd $(ENGINE_DIR) && ZITOU_CLIENT_DIR=$(CURDIR) pnpm dev

translations: ## Exporte les textes du moteur et du site pour les écrans Vue (var/zitou/translations)
	$(CONSOLE) zitou:translations:export

start-d: ## Lance le serveur Symfony en arrière-plan
	symfony serve -d

worker: ## Lance le worker : file des messages et tâches planifiées (Ctrl+C pour l'arrêter)
	$(CONSOLE) messenger:consume zitou_async scheduler_zitou --time-limit=3600 --memory-limit=512M -vv

worker-failed: ## Liste les messages en échec (messenger:failed:retry pour les rejouer)
	$(CONSOLE) messenger:failed:show

check-build-link: ## Vérifie que public/build mène bien aux fichiers compilés du moteur
	@test -L public/build || (echo "public/build doit être un lien vers $(ENGINE_DIR)/public/build" && exit 1)
	@test -e public/build/.vite/manifest.json || (echo "Manifeste introuvable : lancer make build" && exit 1)
	@echo "public/build : OK"

## —— Suivre l'équipe ——
pull-update: ## Après un git pull : dépendances depuis les verrous, migrations, synchronisations, build (données gardées)
	@if [ -f $(ENGINE_UPDATE_MARKER) ] && [ -n "$$(find $(ENGINE_UPDATE_MARKER) -mmin -5)" ]; then \
		echo "make zitou-update vient de monter le moteur : pull-update le ramènerait à la version d'avant."; \
		echo "Faire d'abord git pull puis make pull-zitou-update, ou attendre cinq minutes."; exit 1; fi
	$(MAKE) update-steps

zitou-update: ## Monte le moteur à sa dernière version, puis les mêmes étapes que pull-update
	@if [ -L $(ENGINE_DIR) ]; then \
		echo "Le moteur est relié à ../zitou-core (dépôt local) : rien à monter ici, il suffit d'un git pull dans ../zitou-core."; \
		echo "Les étapes qui suivent une montée sont refaites quand même."; \
	else \
		composer update fblanchon/zitou-core --with-all-dependencies && mkdir -p $(dir $(ENGINE_UPDATE_MARKER)) && touch $(ENGINE_UPDATE_MARKER); \
	fi
	$(MAKE) update-steps
	@echo "Lire la section « Dans zitou-client » du CHANGELOG du moteur : $(ENGINE_DIR)/CHANGELOG.md"

pull-zitou-update: ## git pull fait : suivre l'équipe, puis monter le moteur (le bon ordre)
	$(MAKE) update-steps
	$(MAKE) zitou-update

update-steps: ## (interne) Les étapes communes de pull-update et zitou-update
	composer install
	$(MAKE) engine-deps engine-tools
	$(SYNC) env
	$(CONSOLE) cache:clear
	$(MAKE) migrate params
	$(CONSOLE) zitou:install
	$(SYNC) readme
	$(SYNC) security
	$(SYNC) jsconfig
	$(SYNC) claude
	$(MAKE) build
	$(SYNC) makefile

## —— Base de données et démo ——
db: ## Crée la base, applique les migrations du moteur et du site, installe les données du moteur
	$(CONSOLE) doctrine:database:create --if-not-exists
	$(MAKE) migrate params
	$(CONSOLE) zitou:install

db-reset: ## Supprime la base de développement et la recrée (toutes les données sont perdues, jamais en production)
	@$(MAKE) --no-print-directory refuse-prod
	$(CONSOLE) doctrine:database:drop --force --if-exists
	$(MAKE) db

migrate: ## Joue les migrations en attente (moteur et site, rangées par date)
	$(CONSOLE) doctrine:migrations:migrate --no-interaction --allow-no-migration

migration: ## Écrit la migration qui manque pour les entités du site (dans migrations/)
	$(CONSOLE) doctrine:migrations:diff --namespace=DoctrineMigrations --no-interaction

migration-down: ## Revient d'une migration en arrière
	$(CONSOLE) doctrine:migrations:migrate prev --no-interaction

migrations-check: ## Échoue s'il reste une migration à jouer
	$(CONSOLE) zitou:migrations:check

params: ## Synchronise les paramètres déclarés par les modules, puis les droits
	$(CONSOLE) zitou:application-parameter
	$(CONSOLE) zitou:privileges:sync

schema-check: ## Vérifie que le mapping est valide et que la base de développement le suit
	$(CONSOLE) doctrine:schema:validate

demo: ## Charge les données de démonstration des modules par-dessus la base (rejouable, jamais en production)
	$(CONSOLE) zitou:demo:load

demo-reset: ## Recrée la base, efface les fichiers envoyés et recharge la démo (réglages gardés, jamais en production)
	$(CONSOLE) zitou:demo:reset --no-interaction

demo-pack: ## Charge un pack de démo dans la base, si elle n'a aucune publication : make demo-pack PACK=exemple
	@test -n "$(PACK)" || (echo "Préciser le pack : make demo-pack PACK=exemple (dossier de packs/, chemin ou archive zip)" && exit 1)
	$(CONSOLE) zitou:demo-pack:load $(PACK)

pack-serve: ## Sert un pack de démo à part (sa base, ses fichiers, son hôte) : make pack-serve PACK=exemple [PACK_PORT=8100]
	@test -n "$(PACK)" || (echo "Préciser le pack : make pack-serve PACK=exemple" && exit 1)
	@eval "$$(php $(ENGINE_DIR)/bin/pack-env $(PACK))" && \
		mkdir -p "$$APP_LOG_DIR" "$$ZITOU_UPLOADS_DIR" && \
		$(CONSOLE) doctrine:database:drop --force --if-exists && \
		$(CONSOLE) doctrine:database:create && \
		$(CONSOLE) zitou:database:install && \
		$(CONSOLE) zitou:demo-pack:load $(PACK) && \
		(php -S 127.0.0.1:$(PACK_PORT) -t public > "$$APP_LOG_DIR/server.log" 2>&1 & echo $$! > "$$ZITOU_PACK_DIR/server.pid") && \
		echo "Pack servi sur http://$$ZITOU_PACK_HOST:$(PACK_PORT) ; un compte : make pack-user PACK=$(PACK) ; l'arrêter : make pack-stop PACK=$(PACK)"

pack-user: ## Crée le compte de développement dans la base d'un pack servi à part : make pack-user PACK=exemple
	@test -n "$(PACK)" || (echo "Préciser le pack : make pack-user PACK=exemple" && exit 1)
	@eval "$$(php $(ENGINE_DIR)/bin/pack-env $(PACK))" && $(CONSOLE) zitou:user:create --dev

pack-stop: ## Arrête le pack de démo servi à part : make pack-stop PACK=exemple
	@test -n "$(PACK)" || (echo "Préciser le pack : make pack-stop PACK=exemple" && exit 1)
	@eval "$$(php $(ENGINE_DIR)/bin/pack-env $(PACK))" && \
		if [ -f "$$ZITOU_PACK_DIR/server.pid" ]; then kill "$$(cat "$$ZITOU_PACK_DIR/server.pid")" 2>/dev/null; rm -f "$$ZITOU_PACK_DIR/server.pid"; echo "Pack arrêté."; else echo "Aucun serveur pour ce pack."; fi

## —— Synchronisations ——
sync: ## Toutes les synchronisations avec le moteur
	$(SYNC) all

sync-env: ## Ajoute dans .env les blocs de variables du moteur qui manquent (les valeurs du site restent)
	$(SYNC) env

sync-readme: ## Remplace la partie commune du README (entre ses deux marqueurs)
	$(SYNC) readme

sync-security: ## Recopie la sécurité du moteur dans config/packages/security.yaml (règles du site : security_site.yaml)
	$(SYNC) security

sync-jsconfig: ## Régénère jsconfig.json, qui dit à l'éditeur où sont les composants du moteur
	$(SYNC) jsconfig

sync-claude: ## Refait les liens vers CLAUDE.md, la mémoire et les skills du moteur
	$(SYNC) claude

sync-makefile: ## Recopie ce Makefile depuis le moteur (Makefile.local reste au site)
	$(SYNC) makefile

## —— Qualité ——
cs: ## Corrige le style PHP et Twig
	$(ENGINE_DIR)/tools/php-cs-fixer/vendor/bin/php-cs-fixer fix --config=$(CS_CONFIG)
	$(ENGINE_DIR)/tools/twig-cs-fixer/vendor/bin/twig-cs-fixer lint --fix templates src

cs-check: ## Vérifie le style PHP et Twig sans rien modifier
	$(ENGINE_DIR)/tools/php-cs-fixer/vendor/bin/php-cs-fixer fix --config=$(CS_CONFIG) --dry-run --diff
	$(ENGINE_DIR)/tools/twig-cs-fixer/vendor/bin/twig-cs-fixer lint templates src

rector: ## Applique les corrections de Rector
	$(ENGINE_DIR)/tools/rector/vendor/bin/rector process --config=$(RECTOR_CONFIG)

rector-check: ## Montre les corrections de Rector sans les appliquer
	$(ENGINE_DIR)/tools/rector/vendor/bin/rector process --config=$(RECTOR_CONFIG) --dry-run

phpstan: ## Analyse statique PHPStan au niveau maximum
	$(CONSOLE) cache:warmup --env=dev
	$(ENGINE_DIR)/tools/phpstan/vendor/bin/phpstan analyse --configuration=$(PHPSTAN_CONFIG) --memory-limit=1G

lint: ## Vérifie les gabarits Twig, le YAML et le conteneur
	$(CONSOLE) lint:twig templates src
	$(CONSOLE) lint:yaml config translations src
	$(CONSOLE) lint:container

test: ## PHPUnit (recrée la base de test « _test » à chaque lancement)
	php bin/phpunit

audit: ## Audit de sécurité des dépendances PHP du site et JavaScript du moteur
	composer audit
	cd $(ENGINE_DIR) && pnpm audit --audit-level high

ft: ## Avant chaque commit : style, analyse, schéma, build, tests
	$(MAKE) cs
	$(MAKE) rector-check
	$(MAKE) phpstan
	$(MAKE) lint
	$(MAKE) schema-check
	$(MAKE) build
	$(MAKE) test

## —— Production ——
install-prod: ## Première installation sur le serveur : dépendances, base créée depuis le schéma, build, vérification
	@test -f .env.local || (echo ".env.local manque : APP_ENV=prod, APP_SECRET, ZITOU_ENCRYPTION_KEY, DATABASE_URL, MAILER_DSN… (fiche 36)" && exit 1)
	composer install --no-dev --optimize-autoloader --no-interaction
	$(MAKE) engine-deps
	mkdir -p var/uploads var/share
	$(CONSOLE) doctrine:database:create --if-not-exists
	$(CONSOLE) zitou:database:install
	$(MAKE) params
	$(CONSOLE) zitou:install
	$(MAKE) build
	$(CONSOLE) cache:clear
	$(CONSOLE) cache:warmup
	@echo "Créer le compte de l'administrateur : $(CONSOLE) zitou:user:create"
	$(MAKE) deploy-check

deploy-prod: deploy-guard ## Déploie la version taguée sur HEAD : worker arrêté, dépendances, migrations, build, vérification
	@$(MAKE) --no-print-directory worker-stop
	@$(MAKE) --no-print-directory deploy-steps || { $(MAKE) --no-print-directory worker-start; echo "Déploiement interrompu : le worker a été relancé."; exit 1; }
	@$(MAKE) --no-print-directory worker-start
	$(MAKE) deploy-check

deploy-latest: ## Va chercher le dernier tag de main et le déploie
	git fetch --tags --quiet origin
	@tag=$$(git tag --merged origin/main --list 'v[0-9]*' --sort=-v:refname | head -n 1); \
	test -n "$$tag" || { echo "Aucun tag sur main : rien à déployer."; exit 1; }; \
	git -c advice.detachedHead=false checkout --quiet "$$tag" && echo "Version $$tag"
	$(MAKE) deploy-prod

deploy-check: ## Vérifie le site en production, en lecture seule (version, migrations, worker, page d'accueil)
	@if [ -n "$(WORKER_SERVICE)" ]; then systemctl is-active --quiet $(WORKER_SERVICE) && echo " OK  Service $(WORKER_SERVICE) actif" || { echo " Échec  Service $(WORKER_SERVICE) arrêté"; exit 1; }; fi
	$(CONSOLE) zitou:deploy:check --worker-wait=90

deploy: ## Depuis le PC : déploie le dernier tag sur le serveur (DEPLOY_HOST et DEPLOY_PATH dans Makefile.local)
	@test -n "$(DEPLOY_HOST)" -a -n "$(DEPLOY_PATH)" || (echo "Régler DEPLOY_HOST et DEPLOY_PATH dans Makefile.local" && exit 1)
	ssh $(DEPLOY_HOST) 'cd $(DEPLOY_PATH) && make deploy-latest'

deploy-guard: ## (interne) Refuse de déployer un commit sans tag, ou plus ancien que le dernier tag de main
	@tag=$$(git describe --tags --exact-match HEAD 2>/dev/null) || { echo "HEAD ne porte pas de tag : make deploy-latest déploie le dernier."; exit 1; }; \
	git fetch --tags --quiet origin 2>/dev/null || true; \
	latest=$$(git tag --merged origin/main --list 'v[0-9]*' --sort=-v:refname | head -n 1); \
	if [ -n "$$latest" ] && [ "$$latest" != "$$tag" ] && [ "$$(printf '%s\n%s\n' "$$tag" "$$latest" | sort -V | tail -n 1)" = "$$latest" ]; then \
		echo "main porte $$latest, plus récent que $$tag : make deploy-latest."; exit 1; fi; \
	echo "Déploiement de $$tag"

deploy-steps: ## (interne) Les étapes du déploiement, worker arrêté
	git describe --tags --exact-match HEAD > VERSION
	composer install --no-dev --optimize-autoloader --no-interaction
	$(MAKE) engine-deps
	@echo "Cache vidé une première fois : les commandes qui suivent tournent sur le nouveau code."
	$(CONSOLE) cache:clear
	$(MAKE) migrate params
	$(CONSOLE) zitou:install
	$(MAKE) build
	$(CONSOLE) cache:clear
	$(CONSOLE) cache:warmup
	@if [ -n "$(PHP_FPM_SERVICE)" ]; then sudo systemctl reload $(PHP_FPM_SERVICE) && echo "Cache d'opcodes vidé ($(PHP_FPM_SERVICE) rechargé)"; else echo "PHP_FPM_SERVICE vide : penser à vider le cache d'opcodes de PHP."; fi

worker-stop: ## (interne) Arrête le service du worker, s'il est réglé
	@if [ -n "$(WORKER_SERVICE)" ]; then sudo systemctl stop $(WORKER_SERVICE) && echo "Worker arrêté"; fi

worker-start: ## (interne) Relance le service du worker, s'il est réglé
	@if [ -n "$(WORKER_SERVICE)" ]; then sudo systemctl start $(WORKER_SERVICE) && echo "Worker relancé"; fi

refuse-prod: ## (interne) Refuse de continuer en production
	@if [ "$$(php -r 'echo getenv("APP_ENV") ?: "";')" = "prod" ] || grep -qs '^APP_ENV=prod' .env.local; then echo "Refusé : cette commande efface des données et ne tourne pas en production."; exit 1; fi

help: ## Liste les commandes
	@grep -hE '(^[a-zA-Z_-]+:.*?## .*$$)|(^## )' $(MAKEFILE_LIST) | grep -v '## (interne)' | awk 'BEGIN {FS = ":.*?## "}; /^## /{printf "\n\033[33m%s\033[0m\n", substr($$0, 4); next} {printf "  \033[32m%-18s\033[0m %s\n", $$1, $$2}'

.PHONY: setup-env install install-dev engine-deps engine-tools build dev translations start-d worker worker-failed check-build-link \
	pull-update zitou-update pull-zitou-update update-steps db db-reset migrate migration migration-down migrations-check params \
	schema-check demo demo-reset demo-pack pack-serve pack-user pack-stop sync sync-env sync-readme sync-security sync-jsconfig sync-claude sync-makefile \
	cs cs-check rector rector-check phpstan lint test audit ft install-prod deploy-prod deploy-latest deploy-check deploy \
	deploy-guard deploy-steps worker-stop worker-start refuse-prod help
