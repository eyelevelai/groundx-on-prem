#!/bin/bash
set -e

# Start the MySQL service in the background
docker-entrypoint.sh mysqld &

# Wait for MySQL to be ready
until mysqladmin ping --silent -u root -p"${MYSQL_ROOT_PASSWORD}"; do
    echo "Waiting for MySQL to be up..."
    sleep 2
done

echo "Root password: ${MYSQL_ROOT_PASSWORD}"

# Create the user and grant global privileges for managing databases
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" --default-auth=mysql_native_password -e "
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
"

# Stop the temporary server
mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown

# Restart MySQL server
docker-entrypoint.sh mysqld

