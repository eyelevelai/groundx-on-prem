# Start with the official Red Hat Redis image
FROM opensearchproject/opensearch:latest

# Switch to root user to make changes
USER root

# Create the required directories and set permissions
RUN chown -R 1000:1000 /usr/share/opensearch && \
    chmod -R 777 /usr/share/opensearch

# Set the default user back to the OpenShift random UID
USER 1000
