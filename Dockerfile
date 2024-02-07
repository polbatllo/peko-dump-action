FROM mysql/mysql-server:latest

RUN microdnf install gzip tar openssl wget

# Installs planetscale client
RUN wget https://github.com/planetscale/cli/releases/download/v0.182.0/pscale_0.182.0_linux_amd64.rpm
RUN rpm -ivh pscale_0.182.0_linux_amd64.rpm

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY backup.sh /backup.sh
COPY *.js /github/workspace

CMD ["/backup.sh"]