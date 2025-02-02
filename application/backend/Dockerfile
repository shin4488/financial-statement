FROM ruby:3.2.2

ENV POSTGRES_DATABASE_NAME financial_statement_development
ENV POSTGRES_HOST_NAME database
ENV POSTGRES_PORT 5432
ENV POSTGRES_USER_NAME financial_statement_admin
ENV POSTGRES_PASSWORD admin
ENV REDIS_HOST_NAME cache
ENV REDIS_PORT 6379
ENV SERVER_HOST_NAME appserver

WORKDIR /home/app/financialStatement

COPY docker_setup.sh /home/docker_setup.sh
RUN chmod 111 /home/docker_setup.sh
CMD ["/home/docker_setup.sh"]
