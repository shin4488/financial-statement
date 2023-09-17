CREATE DATABASE financial_statement_development;

\c financial_statement_development;
ALTER DATABASE financial_statement_development SET timezone TO 'UTC';

GRANT ALL PRIVILEGES ON DATABASE financial_statement_development TO financial_statement_admin;
