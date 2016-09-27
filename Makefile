.PHONY: server public deploy

server:
	rm -rf public
	rm -f config.toml
	cp config_local.toml config.toml
	hugo server --watch --verbose -D -F

public:
	rm -rf public
	cp config.toml
	mv config_local.toml config.toml
	hugo

commit:
	git add *

upload:
	rm -rf public
	rm -f config.toml
	cp config_upload.toml config.toml
	hugo
	mv public gafferongames
	zip -9r gafferongames.zip gafferongames
	scp gafferongames.zip root@linux:~/www
	rm gafferongames.zip
	rm gafferongames
	ssh root@linux "cd ~/www && rm -rf gafferongames && unzip gafferongames.zip"

commit:
	rm -rf gafferongames
	git add .
	git commit -am "commit"
	git push
