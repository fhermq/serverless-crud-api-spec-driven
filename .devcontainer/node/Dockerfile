FROM node:20-alpine

# Install system dependencies
RUN apk add --no-cache \
    git \
    curl \
    bash \
    make \
    python3 \
    py3-pip \
    zip

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

# Install SAM CLI
RUN pip3 install aws-sam-cli

# Install global npm packages
RUN npm install -g \
    @aws-sdk/client-dynamodb \
    @aws-sdk/lib-dynamodb \
    jest \
    eslint \
    prettier \
    nodemon

# Set up workspace
WORKDIR /workspace

# Copy package.json files for caching
COPY functions/get-item/package*.json functions/get-item/
COPY functions/update-item/package*.json functions/update-item/

# Install dependencies
RUN cd functions/get-item && npm ci
RUN cd functions/update-item && npm ci

CMD ["bash"]