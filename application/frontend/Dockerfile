FROM ubuntu:20.04

RUN apt update &&\
    apt install -y sudo curl &&\
    # nodeは最新のLTSをインストール（npmも一緒にインストールされる）
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - &&\
    apt install -y nodejs &&\
    npm install -g yarn
# Docker,nginx使用時でも、Reactのホットリロードを有効とするため
ENV WDS_SOCKET_PORT 0

WORKDIR /home/app/financialStatement

COPY docker_setup.sh /home/docker_setup.sh
RUN chmod 111 /home/docker_setup.sh
CMD ["/home/docker_setup.sh"]
