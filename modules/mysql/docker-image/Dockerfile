# Use the official MySQL image from the Docker Hub
FROM mysql:8.0

# Environment variables to configure the MySQL instance
ENV MYSQL_ROOT_PASSWORD=rootpassword
ENV MYSQL_DATABASE=testdatabase
ENV MYSQL_USER=testuser1
ENV MYSQL_PASSWORD=testpassword1

# Copy the entrypoint script into the container
COPY entrypoint.sh /usr/local/bin/

# Make the script executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Ensure the data directory exists and has the correct permissions
RUN mkdir -p /var/lib/mysql && chown -R mysql:mysql /var/lib/mysql

# Set the entrypoint to the custom script
ENTRYPOINT ["entrypoint.sh"]

# Expose the MySQL port
EXPOSE 3306
