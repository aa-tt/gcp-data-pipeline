# Build stage
FROM node:18-alpine AS build

WORKDIR /app

# Accept build arguments for API URLs
ARG VITE_API_URL=https://data-ingestion-dev-rn5o2asova-uc.a.run.app
ARG VITE_ANALYTICS_URL=https://analytics-query-dev-rn5o2asova-uc.a.run.app
ENV VITE_API_URL=$VITE_API_URL
ENV VITE_ANALYTICS_URL=$VITE_ANALYTICS_URL

# Copy package files
COPY package.json ./

# Install dependencies using public npm registry with SSL verification disabled for corporate environments
RUN npm config set registry https://registry.npmjs.org/ && \
    npm config set strict-ssl false && \
    npm install

# Copy source code
COPY . .

# Create .env file with the API URLs
RUN echo "VITE_API_URL=$VITE_API_URL" > .env && \
    echo "VITE_ANALYTICS_URL=$VITE_ANALYTICS_URL" >> .env

# Build the application with the environment variables
RUN npm run build

# Production stage - Use nginx for serving static files
FROM nginx:alpine

# Copy built assets from build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port (Cloud Run uses PORT env variable)
ENV PORT=8080
EXPOSE 8080

# Start nginx
CMD sed -i -e 's/$PORT/'"$PORT"'/g' /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'
