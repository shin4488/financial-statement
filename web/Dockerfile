FROM ubuntu:20.04

RUN apt update &&\
    apt install -y nginx

ENV FLAZA_SERVER_NAME appserver

COPY docker_setup.sh /home/docker_setup.sh
RUN chmod 111 /home/docker_setup.sh
CMD ["/home/docker_setup.sh"]
