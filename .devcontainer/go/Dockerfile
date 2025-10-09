FROM golang:1.21-alpine

# Install system dependencies
RUN apk add --no-cache \
    git \
    curl \
    bash \
    make \
    gcc \
    musl-dev \
    zip

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

# Install SAM CLI
RUN pip3 install aws-sam-cli

# Install Go tools
RUN go install golang.org/x/tools/gopls@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest \
    && go install honnef.co/go/tools/cmd/staticcheck@latest \
    && go install golang.org/x/tools/cmd/goimports@latest

# Set up workspace
WORKDIR /workspace

# Copy Go modules for caching
COPY functions/create-item/go.mod functions/create-item/go.sum functions/create-item/
COPY functions/delete-item/go.mod functions/delete-item/go.sum functions/delete-item/

# Download dependencies
RUN cd functions/create-item && go mod download
RUN cd functions/delete-item && go mod download

# Set environment variables
ENV CGO_ENABLED=0
ENV GOOS=linux
ENV GOARCH=amd64

CMD ["bash"]