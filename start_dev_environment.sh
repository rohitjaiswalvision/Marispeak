#!/bin/bash

# 🚀 Development Environment Startup Script
# This script sets up and starts your development environment for PTT testing

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Starting PTT Development Environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Step 1: Check environment configuration
echo "📋 Step 1: Checking environment configuration..."
echo ""

ENV_FILE="lib/config/environment.dart"
if [ -f "$ENV_FILE" ]; then
    CURRENT_ENV=$(grep "static Environment current" "$ENV_FILE" | grep -o "development\|staging\|production")
    
    if [ "$CURRENT_ENV" = "development" ]; then
        print_success "Environment set to: $CURRENT_ENV"
        echo "   You're ready to test safely!"
    elif [ "$CURRENT_ENV" = "staging" ]; then
        print_warning "Environment set to: $CURRENT_ENV"
        echo "   Using staging server, not local development"
    else
        print_warning "Environment set to: $CURRENT_ENV"
        echo "   ⚠️  WARNING: You're using PRODUCTION!"
        echo "   Consider switching to 'development' for safe testing"
        echo ""
        read -p "   Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "   Exiting..."
            exit 1
        fi
    fi
else
    print_error "Environment config file not found!"
    echo "   Expected: $ENV_FILE"
    exit 1
fi

echo ""

# Step 2: Check if server directory exists
echo "📂 Step 2: Checking PTT server..."
echo ""

SERVER_DIR="railway_server"
if [ -d "$SERVER_DIR" ]; then
    print_success "Server directory found: $SERVER_DIR"
else
    print_error "Server directory not found: $SERVER_DIR"
    echo "   Please ensure your PTT server code is in the $SERVER_DIR directory"
    exit 1
fi

echo ""

# Step 3: Check Node.js installation
echo "🔧 Step 3: Checking Node.js installation..."
echo ""

if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    print_success "Node.js installed: $NODE_VERSION"
else
    print_error "Node.js not installed!"
    echo "   Install Node.js from: https://nodejs.org/"
    exit 1
fi

if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    print_success "npm installed: $NPM_VERSION"
else
    print_error "npm not installed!"
    exit 1
fi

echo ""

# Step 4: Install server dependencies
echo "📦 Step 4: Installing server dependencies..."
echo ""

cd "$SERVER_DIR" || exit 1

if [ ! -d "node_modules" ]; then
    print_warning "Dependencies not installed. Installing now..."
    npm install
    if [ $? -eq 0 ]; then
        print_success "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi
else
    print_success "Dependencies already installed"
fi

echo ""

# Step 5: Check server port
echo "🔌 Step 5: Checking if port 3000 is available..."
echo ""

if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    print_warning "Port 3000 is already in use"
    echo "   Another server might be running"
    echo "   Attempting to continue anyway..."
else
    print_success "Port 3000 is available"
fi

echo ""

# Step 6: Start the server
echo "🚀 Step 6: Starting PTT development server..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "Server starting on ws://localhost:3000"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Next steps:"
echo "   1. Keep this terminal window open"
echo "   2. Open a new terminal"
echo "   3. Run: flutter run"
echo "   4. Test your PTT feature!"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Start the server
npm start

# If server exits
echo ""
print_warning "Server stopped"
