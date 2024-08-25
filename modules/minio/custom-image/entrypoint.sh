#!/bin/sh

# Start MinIO server in the background
minio server /data --console-address :9001 &

# Wait for MinIO to start up
sleep 10

# Set the alias for the MinIO client (mc)
mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD

# Add a new user with different credentials from the root user
NEW_USER_ACCESS_KEY="newuseraccesskey"
NEW_USER_SECRET_KEY="newusersecretkey"
mc admin user add local $NEW_USER_ACCESS_KEY $NEW_USER_SECRET_KEY

# Wait for the MinIO server to keep running
wait -n
