[Demo site](http://humboldtux.github.io/sbcb-demo/) for [Start Bootstrap Clean Blog](http://startbootstrap.com/template-overviews/clean-blog/) ported to a Hugo theme.

# Instructions

This demo site has been setup with the following commands.

## Create a new site

    hugo new site sbcb-demo
    cd sbcb-demo

## Init repo and  master branch

    git init
    git remote add origin git@github.com:humboldtux/sbcb-demo.git
    git add .
    git commit -m "Initial commit"
    git push --set-upstream origin master
    git push

## Create gh-pages branch

    git checkout --orphan gh-pages
    git rm --cached $(git ls-files)
    rm -f *
    touch index.html
    git add index.html
    git commit -m "Initial commit on gh-pages branch"
    git push origin gh-pages

## Clone Theme repo

    git checkout master
    git clone https://github.com/humboldtux/startbootstrap-clean-blog.git themes/startbootstrap-clean-blog
    nano .gitignore

## Edit ***config.toml***

Have a look at the ***config.toml*** in this repository as a starting point.

## Add about and contact pages

    hugo new about.md
    hugo new contact.md

You need to set the type to ***about*** for *about.md*, and ***contact*** for *contact.md*.
You can change the title too.
Have a look at the files *content/about.md* and *content/contact.md* for a starting point.

## Contact page and formspree.io

The contact page uses formspree.io to send emails without requiring a backend scripting langage.

For formspree.io to work, you need to change dummy@dummy.com in **themes/startbootstrap-clean-blog/static/js/clean-blog.js**, line 29,
with your email, as i don't know yet how to update a static file with a Hugo configuration variable.

For you to avoid editing directly the theme file, a nicer way to do it is to copy this file in your site *static/js* directory, and then edit it:

    mkdir static/js
    sed -i s/dummy@dummy.com/my@email.com/g static/js/clean-blog.js

## Add some posts

    for i in {01..10};do hugo new post/post-${i}.md;done

## Check site

    hugo server --watch --verbose -D -F

If it's ok, remove ***draft = "true"*** from *content/post/* files.

## Commit site

    rm -rf public
    git add .
    git commit -m'Add base content'

## Configure gh-pages subtree to **public** directory

    git subtree add --prefix=public git@github.com:humboldtux/sbcb-demo.git gh-pages --squash
    git subtree pull --prefix=public git@github.com:humboldtux/sbcb-demo.git gh-pages --squash

## Generate site

    hugo

## Commit **public** content

    git add -A
    git commit -m "Updating site"

## Deploy **public** content to remote gh-pages

    git push origin master
    git subtree push --prefix=public git@github.com:humboldtux/sbcb-demo.git gh-pages --squash
