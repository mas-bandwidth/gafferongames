FROM nginx

RUN apt-get update && apt-get install -y wget

ENV DOCKERIZE_VERSION v0.4.0

RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

ADD public /var/www/html/gafferongames

ADD nginx.conf /etc/nginx/nginx.conf

WORKDIR /etc/nginx

CMD "dockerize -wait tcp://web:8080 nginx"

EXPOSE 80

EXPOSE 443
