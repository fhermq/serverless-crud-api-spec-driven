# 💻 VS Code Setup Guide for Serverless CRUD API

This guide helps you set up and use the Serverless CRUD API project in Visual Studio Code for the best development experience.

## 🚀 Quick Answer

**Yes, you can use the `STEP_BY_STEP_DEPLOYMENT_GUIDE.md` directly in VS Code!** The commands work exactly the same. However, VS Code offers additional features that make development easier.

## 📋 Prerequisites

### Required Tools (Same as Step-by-Step Guide)
```bash
# Check if tools are installed
aws --version        # AWS CLI 2.x.x+
sam --version        # SAM CLI 1.x.x+
go version          # Go 1.21.x+
node --version      # Node.js 18.x.x+ or 20.x.x+
npm --version       # npm 8.x.x+
```

### VS Code Extensions (Recommended)
Install these extensions for the best experience:

```bash
# Essential Extensions
code --install-extension ms-vscode.vscode-json
code --install-extension redhat.vscode-yaml
code --install-extension ms-vscode.powershell
code --install-extension ms-vscode.vscode-typescript-next

# AWS Extensions
code --install-extension amazonwebservices.aws-toolkit-vscode
code --install-extension amazonwebservices.amazon-q-vscode

# Go Extensions
code --install-extension golang.go

# Docker Extensions (for local testing)
code --install-extension ms-azuretools.vscode-docker
```

## 🔧 VS Code Workspace Setup

### 1. Open Project in VS Code
```bash
# Navigate to your project
cd /path/to/your/serverless-crud-api

# Open in VS Code
code .
```

### 2. Configure VS Code Workspace Settings
Create `.vscode/settings.json`:

```json
{
  "go.toolsManagement.checkForUpdates": "local",
  "go.useLanguageServer": true,
  "go.gopath": "",
  "go.goroot": "",
  "go.lintOnSave": "package",
  "go.formatTool": "goimports",
  "go.buildOnSave": "off",
  "typescript.preferences.importModuleSpecifier": "relative",
  "yaml.schemas": {
    "https://raw.githubusercontent.com/aws/serverless-application-model/main/samtranslator/schema/schema.json": [
      "infrastructure/stacks/*.yaml",
      "infrastructure/stacks/*.yml"
    ]
  },
  "files.associations": {
    "*.yaml": "yaml",
    "*.yml": "yaml"
  },
  "terminal.integrated.defaultProfile.osx": "zsh",
  "terminal.integrated.defaultProfile.linux": "bash",
  "terminal.integrated.defaultProfile.windows": "PowerShell"
}
```

### 3. Create VS Code Tasks
Create `.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Deploy All Stacks",
      "type": "shell",
      "command": "./scripts/deploy-all.sh",
      "args": ["--stage", "dev", "--region", "us-east-1"],
      "group": "build",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": false,
        "panel": "shared"
      },
      "options": {
        "cwd": "${workspaceFolder}/infrastructure"
      },
      "problemMatcher": []
    },
    {
      "label": "Enable API Key",
      "type": "shell",
      "command": "./scripts/manage-api-key.sh",
      "args": ["enable-auth", "--stage", "dev"],
      "group": "build",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": false,
        "panel": "shared"
      },
      "options": {
        "cwd": "${workspaceFolder}/infrastructure"
      },
      "problemMatcher": []
    },
    {
      "label": "Get API Key",
      "type": "shell",
      "command": "./scripts/manage-api-key.sh",
      "args": ["get-key", "--stage", "dev"],
      "group": "build",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": false,
        "panel": "shared"
      },
      "options": {
        "cwd": "${workspaceFolder}/infrastructure"
      },
      "problemMatcher": []
    },
    {
      "label": "Cleanup All Stacks",
      "type": "shell",
      "command": "./scripts/cleanup.sh",
      "args": ["--stage", "dev", "--region", "us-east-1"],
      "group": "build",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": false,
        "panel": "shared"
      },
      "options": {
        "cwd": "${workspaceFolder}/infrastructure"
      },
      "problemMatcher": []
    },
    {
      "label": "Build Go Functions",
      "type": "shell",
      "command": "GOOS=linux GOARCH=amd64 go build -o bootstrap main.go logger.go",
      "group": "build",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": false,
        "panel": "shared"
      },
      "options": {
        "cwd": "${workspaceFolder}/functions/create-item"
      },
      "problemMatcher": ["$go"]
    },
    {
      "label": "Install Node.js Dependencies",
      "type": "shell",
      "command": "npm install",
      "group": "build",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": false,
        "panel": "shared"
      },
      "options": {
        "cwd": "${workspaceFolder}/functions/get-item"
      },
      "problemMatcher": ["$node-sass"]
    }
  ]
}
```

### 4. Create Launch Configuration
Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug Go Function (Create Item)",
      "type": "go",
      "request": "launch",
      "mode": "debug",
      "program": "${workspaceFolder}/functions/create-item",
      "env": {
        "DYNAMODB_TABLE_NAME": "serverless-crud-api-dev-items",
        "STAGE": "dev",
        "LOG_LEVEL": "DEBUG"
      },
      "args": []
    },
    {
      "name": "Debug Go Function (Delete Item)",
      "type": "go",
      "request": "launch",
      "mode": "debug",
      "program": "${workspaceFolder}/functions/delete-item",
      "env": {
        "DYNAMODB_TABLE_NAME": "serverless-crud-api-dev-items",
        "STAGE": "dev",
        "LOG_LEVEL": "DEBUG"
      },
      "args": []
    }
  ]
}
```

## 🚀 Using the Step-by-Step Guide in VS Code

### Method 1: Integrated Terminal (Recommended)
```bash
# Open integrated terminal in VS Code (Ctrl+` or Cmd+`)
# Navigate to infrastructure directory
cd infrastructure

# Follow the exact same commands from STEP_BY_STEP_DEPLOYMENT_GUIDE.md
./scripts/deploy-all.sh --stage dev --region us-east-1
```

### Method 2: VS Code Tasks (GUI)
1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
2. Type "Tasks: Run Task"
3. Select from available tasks:
   - "Deploy All Stacks"
   - "Enable API Key"
   - "Get API Key"
   - "Cleanup All Stacks"

### Method 3: Command Palette
1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
2. Type "Terminal: Create New Terminal"
3. Run commands from the step-by-step guide

## 🔧 VS Code Specific Features

### AWS Toolkit Integration
After installing AWS Toolkit extension:

1. **Configure AWS Profile:**
   - Open Command Palette (`Ctrl+Shift+P`)
   - Type "AWS: Create Credentials Profile"
   - Follow the prompts

2. **View AWS Resources:**
   - Open AWS Explorer in sidebar
   - Browse Lambda functions, DynamoDB tables, etc.

3. **Invoke Functions Locally:**
   - Right-click on Lambda function in AWS Explorer
   - Select "Invoke on AWS" or "Invoke Locally"

### SAM Integration
```bash
# Initialize SAM in VS Code terminal
sam init

# Build and test locally
sam build
sam local start-api

# Deploy from VS Code terminal
sam deploy --guided
```

### Go Development Features
With Go extension installed:

1. **Auto-completion and IntelliSense**
2. **Go to Definition** (`F12`)
3. **Format on Save** (automatically runs `gofmt`)
4. **Integrated Testing** (`Ctrl+F5`)
5. **Debugging Support**

### Node.js Development Features
1. **NPM Script Runner** (in Explorer sidebar)
2. **Integrated Debugging**
3. **Auto-import suggestions**
4. **ESLint integration**

## 📁 Recommended Folder Structure in VS Code

```
serverless-crud-api/
├── .vscode/                    # VS Code configuration
│   ├── settings.json          # Workspace settings
│   ├── tasks.json             # Build tasks
│   └── launch.json            # Debug configuration
├── functions/                  # Lambda functions
│   ├── create-item/           # Go function
│   ├── get-item/              # Node.js function
│   ├── update-item/           # Node.js function
│   └── delete-item/           # Go function
├── infrastructure/             # AWS SAM templates
├── docs/                      # Documentation
├── shared/                    # Shared utilities
└── README.md                  # Project overview
```

## 🧪 Testing in VS Code

### 1. API Testing with REST Client Extension
Install REST Client extension:
```bash
code --install-extension humao.rest-client
```

Create `test-api.http`:
```http
### Get API URL first
@api_url = https://your-api-id.execute-api.us-east-1.amazonaws.com/dev
@api_key = your-api-key-here

### Test GET (without API key - should fail)
GET {{api_url}}/items/test-123

### Test GET (with API key - should work)
GET {{api_url}}/items/test-123
X-API-Key: {{api_key}}

### Test POST (create item)
POST {{api_url}}/items
Content-Type: application/json
X-API-Key: {{api_key}}

{
  "name": "VS Code Test Item",
  "description": "Created from VS Code",
  "category": "test",
  "price": 99.99
}
```

### 2. Local SAM Testing
```bash
# In VS Code terminal
cd infrastructure
sam local start-api --template-file stacks/02-api-and-functions.yaml

# Test locally
curl http://localhost:3000/items/test-123
```

## 🔍 Debugging in VS Code

### Debug Go Functions
1. Set breakpoints in Go code
2. Press `F5` or use Debug panel
3. Select "Debug Go Function (Create Item)"
4. Function runs with debugger attached

### Debug Node.js Functions
1. Set breakpoints in JavaScript code
2. Use integrated Node.js debugger
3. Inspect variables and call stack

### Debug SAM Applications
```bash
# Debug with SAM CLI
sam local start-api --debug-port 5858
```

## 📊 Monitoring in VS Code

### CloudWatch Logs
With AWS Toolkit:
1. Open AWS Explorer
2. Navigate to CloudWatch → Log Groups
3. View logs directly in VS Code

### Lambda Function Metrics
1. Right-click function in AWS Explorer
2. Select "View Function Metrics"
3. See invocation count, duration, errors

## 🚨 Troubleshooting in VS Code

### Common Issues

#### 1. Go Module Issues
```bash
# In VS Code terminal
cd functions/create-item
go mod tidy
go mod download
```

#### 2. Node.js Dependency Issues
```bash
# In VS Code terminal
cd functions/get-item
rm -rf node_modules package-lock.json
npm install
```

#### 3. AWS Credentials
```bash
# Check AWS configuration
aws configure list
aws sts get-caller-identity
```

### VS Code Specific Troubleshooting

#### 1. Extension Issues
- Reload VS Code window (`Ctrl+Shift+P` → "Developer: Reload Window")
- Check extension logs in Output panel

#### 2. Terminal Issues
- Use integrated terminal instead of external terminal
- Check terminal shell configuration in settings

#### 3. IntelliSense Issues
- Restart Go language server (`Ctrl+Shift+P` → "Go: Restart Language Server")
- Reload TypeScript service for Node.js files

## 🎯 VS Code Workflow Summary

### Daily Development Workflow
1. **Open VS Code** → `code .`
2. **Open Terminal** → `Ctrl+\`` 
3. **Follow Step-by-Step Guide** → Use exact same commands
4. **Use VS Code Tasks** → `Ctrl+Shift+P` → "Tasks: Run Task"
5. **Test API** → Use REST Client or integrated terminal
6. **Debug Issues** → Use integrated debugger and AWS Toolkit

### Key Advantages in VS Code
- ✅ **Same commands work** - No changes needed to step-by-step guide
- ✅ **Integrated terminal** - Run scripts directly in VS Code
- ✅ **AWS integration** - View resources and logs
- ✅ **Debugging support** - Debug Go and Node.js functions
- ✅ **IntelliSense** - Auto-completion and error detection
- ✅ **Git integration** - Built-in version control

## 🎉 Conclusion

**The `STEP_BY_STEP_DEPLOYMENT_GUIDE.md` works perfectly in VS Code!** 

Just use the integrated terminal and follow the exact same commands. The VS Code extensions and configuration above will enhance your development experience but are not required for deployment.

**Quick Start in VS Code:**
1. Open project: `code .`
2. Open terminal: `Ctrl+\``
3. Follow step-by-step guide: `cd infrastructure && ./scripts/deploy-all.sh --stage dev --region us-east-1`

That's it! 🚀