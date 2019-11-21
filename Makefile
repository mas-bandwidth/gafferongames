.PHONY: local

local:
	bash -c "sleep 0.25 && /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome http://127.0.0.1:1313" &
	mkdir -p public/static
	hugo server --watch -D -F
