.PHONY: local upload commit

local:
	rm -rf public
	rm -f config.toml
	cp config_local.toml config.toml
	open http://127.0.0.1:1313
	hugo server --watch --verbose -D -F

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
	open http://linux/gafferongames

commit:
	rm -rf gafferongames
	git add .
	git commit -am "commit"
	git push
