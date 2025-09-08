# Start with the official Red Hat Redis image
FROM registry.redhat.io/rhel8/redis-6:latest

# Switch to root user to make changes
USER root

# Ensure the Redis user can read the configuration file
RUN chown 1001:1001 /etc/redis.conf \
    && chmod 777 /etc/redis.conf

# Create the required directories and set permissions
RUN mkdir -p /mnt/redis && \
    chown -R 1001:1001 /mnt/redis && \
    chown -R 1001:1001 /var/lib/redis && \
    chown -R 1001:1001 /etc/redis.conf && \
    chmod -R 777 /etc/redis.conf && \
    chmod -R 777 /var/lib/redis && \
    chmod -R 777 /mnt/redis

# Set the default user back to the OpenShift random UID
USER 1001

# Start Redis server when the container starts
CMD ["redis-server", "/etc/redis.conf"]
