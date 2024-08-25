# Base image with MySQL
FROM mysql:8.0

# Set environment variables (these can also be passed during container runtime)
ENV MYSQL_ROOT_PASSWORD=rootpassword
ENV MYSQL_USER=user
ENV MYSQL_PASSWORD=userpassword

# Copy the entrypoint script into the container
COPY entrypoint.sh /usr/local/bin/

# Make the entrypoint script executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Define the entrypoint script to run when the container starts
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Expose MySQL port
EXPOSE 3306

