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
	scp gafferongames_upload.zip gaffer@linux:~/
	rm gafferongames_upload.zip
	rm -rf gafferongames_upload
	ssh -t gaffer@linux "sudo mv ~/gafferongames_upload.zip /var/www/html && cd /var/www/html && sudo rm -rf gafferongames_upload && sudo unzip gafferongames_upload.zip && sudo rm -rf video && sudo mv gafferongames/video video && sudo rm -rf gafferongames && sudo mv gafferongames_upload gafferongames && sudo mv video gafferongames/video"
	open http://new.gafferongames.com
	rm -f config.toml

upload_video: clean
	zip -9r video.zip video
	scp video.zip gaffer@linux:~/
	rm video.zip
	ssh -t gaffer@linux "sudo mv ~/video.zip /var/www/html && cd /var/www/html && sudo rm -rf video && sudo unzip video.zip && sudo rm -rf gafferongames/video && sudo mv video gafferongames/video"

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
