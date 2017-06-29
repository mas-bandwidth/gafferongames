FROM golang

RUN apt-get -y update

RUN go get github.com/gorilla/mux
RUN go get github.com/gorilla/context
RUN go get -u github.com/go-redis/redis

ADD webserver.go webserver.go

RUN go build -o /go/bin/webserver webserver.go

WORKDIR /go/bin

ENTRYPOINT /go/bin/webserver

EXPOSE 8080
