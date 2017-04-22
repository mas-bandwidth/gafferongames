.PHONY: docker background

clean:
	-docker kill nginx
	-docker rm nginx

build:
	docker build -t networkprotocol:nginx .

docker:	clean build
	docker run --name nginx -ti -p 80:80 -p 443:443 networkprotocol:nginx

background: clean build
	sudo -b docker run --name nginx -p 80:80 -p 443:443 networkprotocol:nginx
