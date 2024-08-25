#!/bin/bash
set -e

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Check for required environment variables
if [[ -z "${MYSQL_ROOT_PASSWORD}" || -z "${MYSQL_USER}" || -z "${MYSQL_PASSWORD}" ]]; then
    log "Error: Required environment variables (MYSQL_ROOT_PASSWORD, MYSQL_USER, MYSQL_PASSWORD) are not set."
    exit 1
fi

# Start the MySQL service in the background
log "Starting MySQL service..."
docker-entrypoint.sh mysqld &

# Wait for MySQL to be ready
log "Waiting for MySQL to be up..."
until mysqladmin ping --silent -u root -p"${MYSQL_ROOT_PASSWORD}"; do
    log "MySQL is still starting..."
    sleep 2
done

log "MySQL is up and running."

# Create the user and grant global privileges for managing databases
# log "Creating user '${MYSQL_USER}' and granting privileges..."
# mysql -u root -p"${MYSQL_ROOT_PASSWORD}" --default-auth=mysql_native_password -e "
# CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
# GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_USER}'@'%';
# FLUSH PRIVILEGES;
# " || { log "Error creating user or granting privileges."; exit 1; }

# log "User '${MYSQL_USER}' created successfully."

# Stop the temporary server
log "Stopping MySQL service for restart..."
mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown || { log "Error shutting down MySQL."; exit 1; }

# Restart MySQL server
log "Restarting MySQL service..."
docker-entrypoint.sh mysqld || { log "Error restarting MySQL."; exit 1; }

log "MySQL service restarted successfully."

# Keep the container running
wait -n
