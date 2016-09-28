.PHONY: local upload commit

local:
	rm -rf public
	rm -f config.toml
	cp config_local.toml config.toml
	bash -c "sleep 0.25 && open http://127.0.0.1:1313" &
	hugo server --watch --verbose -D -F
	rm -f config.toml

upload:
	rm -rf public
	rm -f config.toml
	cp config_upload.toml config.toml
	hugo
	mv public gafferongames
	zip -9r gafferongames.zip gafferongames
	scp gafferongames.zip root@linux:~/www
	rm gafferongames.zip
	rm -rf gafferongames
	ssh root@linux "cd ~/www && rm -rf gafferongames && unzip gafferongames.zip"
	open http://linux/gafferongames
	rm -f config.toml

commit:
	rm -rf gafferongames
	rm -f config.toml
	git add .
	git commit -am "commit"
	git push
