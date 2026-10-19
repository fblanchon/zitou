DEPLOY_HOST ?= monvps
DEPLOY_PATH ?= /var/www/zitou

.PHONY: serve stop deploy

serve:
	symfony serve -d --no-tls

stop:
	symfony server:stop

deploy:
	git push
	ssh $(DEPLOY_HOST) $(DEPLOY_PATH)/bin/deploy.sh

