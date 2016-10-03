.PHONY: public local upload commit clean

public: 
	rm -rf public
	rm -f config.toml
	cp config_upload.toml config.toml
	hugo

local:
	rm -f config.toml
	cp config_local.toml config.toml
	bash -c "sleep 1.0 && open http://127.0.0.1:1313" &
	hugo server --watch --verbose -D -F
	rm -f config.toml

upload:
	rm -rf public
	rm -f config.toml
	cp config_upload.toml config.toml
	hugo
	mv public gafferongames_upload
	zip -9r gafferongames_upload.zip gafferongames_upload
	scp gafferongames_upload.zip root@linux:~/www
	rm gafferongames_upload.zip
	rm -rf gafferongames_upload
	ssh root@linux "cd ~/www && unzip gafferongames_upload.zip && rm -rf gafferongames_old && mv gafferongames gafferongames_old && mv gafferongames_upload gafferongames && rm -rf gafferongames_old"
	open http://linux/gafferongames
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

integration_basics:
	mkdir -p bin
	g++ source/game_physics/integration_basics.cpp -o bin/integration_basics
	cd bin && ./integration_basics
