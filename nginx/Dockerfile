FROM nginx

ADD public /var/www/html/gafferongames

ADD nginx.conf /etc/nginx/nginx.conf

WORKDIR /etc/nginx

RUN ["nginx"]

EXPOSE 80

EXPOSE 443
