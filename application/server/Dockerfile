FROM ruby:3.1.2

ENV FINANCIAL_STATEMENT_DATABASE_NAME financial_statement_development
ENV FINANCIAL_STATEMENT_DATABASE_HOST_NAME database
ENV FINANCIAL_STATEMENT_DATABASE_PORT 5432
ENV FINANCIAL_STATEMENT_DATABASE_USER_NAME financial_statement_admin
ENV FINANCIAL_STATEMENT_DATABASE_PASSWORD admin

WORKDIR /home/app/financialStatement

COPY docker_setup.sh /home/docker_setup.sh
RUN chmod 111 /home/docker_setup.sh
CMD ["/home/docker_setup.sh"]
