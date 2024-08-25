# Use the official MinIO image from Quay.io as the base image
FROM quay.io/minio/minio

# Set environment variables for MinIO root user and password
ENV MINIO_ROOT_USER=ROOTNAME
ENV MINIO_ROOT_PASSWORD=CHANGEME123

# Expose ports 9000 and 9001
EXPOSE 9000
EXPOSE 9001

# Copy a custom startup script to the container
COPY entrypoint.sh /usr/bin/entrypoint.sh

# Make the script executable
RUN chmod +x /usr/bin/entrypoint.sh

# Set the entrypoint to run the custom script
ENTRYPOINT ["/usr/bin/entrypoint.sh"]

# Set the default command to start the MinIO server
CMD ["minio", "server", "/data", "--console-address", ":9001"]
