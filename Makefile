.PHONY: video public local upload commit clean

public: video
	rm -rf public
	rm -f config.toml
	cp config_upload.toml config.toml
	hugo

local:
	rm -f config.toml
	cp config_local.toml config.toml
	bash -c "sleep 2.5 && open http://127.0.0.1:1313" &
	mkdir -p public/static
	cp -r video static/video
	hugo server --watch --verbose -D -F
	rm -f config.toml

upload: clean
	rm -rf static/video
	cp config_upload.toml config.toml
	hugo
	mv public gafferongames_upload
	zip -9r gafferongames_upload.zip gafferongames_upload
	scp gafferongames_upload.zip root@linux:/var/www/html
	rm gafferongames_upload.zip
	rm -rf gafferongames_upload
	ssh gaffer@linux "cd /var/www/html && rm -rf gafferongames_upload && unzip gafferongames_upload.zip && rm -rf video && mv gafferongames/video video && rm -rf gafferongames && mv gafferongames_upload gafferongames && mv video gafferongames/video"
	open http://linux/gafferongames
	rm -f config.toml

upload_video: clean
	zip -9r video.zip video
	scp video.zip root@linux:/var/www/html
	rm video.zip
	ssh gaffer@linux "cd /var/www/html && rm -rf video && unzip video.zip && rm -rf gafferongames/video && mv video gafferongames/video"

commit: clean
	git add .
	git commit -am "commit"
	git push

clean: 
	rm -rf bin
	rm -rf public
	rm -rf video_upload
	rm -rf gafferongames_upload
	rm -rf static/video
	rm -f video_upload.zip
	rm -f gafferongames_upload.zip
	rm -f config.toml
	find . -name .DS_Store -delete

integration_basics:
	mkdir -p bin
	g++ source/game_physics/integration_basics.cpp -o bin/integration_basics
	cd bin && ./integration_basics
