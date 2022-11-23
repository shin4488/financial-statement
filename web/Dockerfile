FROM ubuntu:20.04

RUN apt update &&\
    apt install -y nginx

CMD ["nginx", "-g", "daemon off;", "-c", "/etc/nginx/nginx.conf"]
