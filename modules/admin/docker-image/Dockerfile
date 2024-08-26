# Base image
FROM python:3.12-slim

# Set the working directory
WORKDIR /app

# Copy only the necessary files
COPY . .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Expose the port the app runs on
EXPOSE 8080

# Command to run both the Flask server and Redis client
CMD ["python", "server.py"]
