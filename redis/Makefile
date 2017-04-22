.PHONY: docker background clean

build:
	docker build -t networkprotocol:redis-server .

clean:
	-docker kill redis
	-docker rm redis

docker:	clean build
	docker run --name redis -ti -p 6379:6379 networkprotocol:redis-server

background: clean build
	sudo -b docker run --name redis networkprotocol:redis-server
