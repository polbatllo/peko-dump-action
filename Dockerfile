FROM mysql/mysql-server:latest

RUN microdnf install gzip tar

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY backup.sh /backup.sh

CMD ["/backup.sh"]