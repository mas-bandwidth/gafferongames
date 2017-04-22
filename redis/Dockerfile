FROM phusion/baseimage:0.9.18

run apt-get update && apt-get install -y redis-server

expose 6379

entrypoint ["/usr/bin/redis-server"]
