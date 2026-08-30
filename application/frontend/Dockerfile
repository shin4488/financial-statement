FROM ubuntu:20.04

RUN apt update &&\
    apt install -y sudo curl &&\
    # nodeのバージョンは.nvmrc・CIと揃える（npmも一緒にインストールされる）。
    # setup_lts.x だとイメージのビルド時期でバージョンが変わり、CIとズレる
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - &&\
    apt install -y nodejs &&\
    npm install -g yarn
# Docker,nginx使用時でも、Reactのホットリロードを有効とするため
ENV WDS_SOCKET_PORT 0

WORKDIR /home/app/financialStatement

COPY docker_setup.sh /home/docker_setup.sh
RUN chmod 111 /home/docker_setup.sh
CMD ["/home/docker_setup.sh"]
