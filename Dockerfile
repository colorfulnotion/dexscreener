# Use official MySQL image as base
FROM mysql:latest

# Set environment variables
ENV MYSQL_DATABASE blocks_db
ENV MYSQL_ROOT_PASSWORD root

# Copy SQL script to initialize database
COPY ./init.sql /docker-entrypoint-initdb.d/

# Expose MySQL port
EXPOSE 3306

# Use official Node.js image as base for the second stage
FROM node:latest

# Set working directory
WORKDIR /app

# Copy package.json and package-lock.json to install dependencies
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Expose port for Node.js application
EXPOSE 3000

# Command to start the Node.js application
CMD ["node", "app.js"]
