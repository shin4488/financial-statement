FROM ubuntu/postgres:12-20.04_beta

RUN apt update

ENV TZ Asia/Tokyo
ENV POSTGRES_USER financial_statement_admin
ENV POSTGRES_PASSWORD admin
ENV POSTGRES_INITDB_ARGS="--encoding=UTF-8 --locale=C"
