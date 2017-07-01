.PHONY: public local upload commit clean nginx redis webserver wordpress build up down

public:
	rm -rf public
	rm -f config.toml
	cp config_upload.toml config.toml
	hugo

local:
	rm -f config.toml
	cp config_local.toml config.toml
	bash -c "sleep 0.25 && /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome http://127.0.0.1:1313" &
	mkdir -p public/static
	hugo server --watch -D -F
	rm -f config.toml

commit: clean
	git add .
	git commit -am "commit"
	git push

clean: 
	rm -rf bin
	rm -rf public
	rm -rf gafferongames_upload
	rm -f gafferongames_upload.zip
	rm -f config.toml
	find . -name .DS_Store -delete
	-docker kill nginx redis webserver > /dev/null 2>&1; exit 0
	-docker rm nginx redis webserver > /dev/null 2>&1; exit 0

integration_basics:
	mkdir -p bin
	g++ source/game_physics/integration_basics.cpp -o bin/integration_basics
	cd bin && ./integration_basics

nginx: public
	-docker kill nginx > /dev/null 2>&1; exit 0
	-docker rm nginx > /dev/null 2>&1; exit 0
	docker build -t gafferongames:nginx nginx
	docker run --name nginx --depends webserver -ti -p 80:80 -p 443:443 -v ~/gafferongames/public:/var/www/html/gafferongames:ro gafferongames:nginx

redis:
	-docker kill redis > /dev/null 2>&1; exit 0
	-docker rm redis > /dev/null 2>&1; exit 0
	docker build -t gafferongames:redis redis
	docker run --name redis -ti -p 6379:6379 gafferongames:redis

webserver:
	-docker kill webserver > /dev/null 2>&1; exit 0
	-docker rm webserver > /dev/null 2>&1; exit 0
	docker build -t gafferongames:webserver webserver
	docker run --name webserver --depends redis -ti -p 8080:8080 -v ~/gafferongames/videos:/go/bin/videos:ro gafferongames:webserver

wordpress:
	-docker kill wordpress > /dev/null 2>&1; exit 0
	-docker rm wordpress > /dev/null 2>&1; exit 0
	docker build -t gafferongames:wordpress wordpress
	docker run --name wordpress -ti -p 8000:80 gafferongames:wordpress

build: public
	docker-compose build

up:
	sudo -b docker-compose up

down:
	docker-compose down

sync:
	git pull && make build && make down && make up
