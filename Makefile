.PHONY: server public deploy

server:
	rm -rf public
	hugo server --watch --verbose -D -F

public:
	git rm -rf public
	hugo

deploy:
	git subtree push --prefix=public git@github.com:humboldtux/sbcb-demo.git gh-pages --squash
