#!/bin/bash

# Simple smoke test for CI/CD
# This script tests basic functionality without requiring extensive setup

echo "🧪 Running Redis Bloom Filter Smoke Tests..."

# Check if dist directory exists
if [ ! -d "dist" ]; then
    echo "❌ dist/ directory not found. Run 'npm run build' first."
    exit 1
fi

# Check if required files exist
REQUIRED_FILES=(
    "dist/index.js"
    "dist/web-server.js"
    "dist/advanced-cache-manager.js"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Required file not found: $file"
        exit 1
    else
        echo "✅ Found: $file"
    fi
done

# Test if Node.js can load the modules (syntax check)
echo "🔍 Checking JavaScript syntax..."

for file in "${REQUIRED_FILES[@]}"; do
    if node -c "$file"; then
        echo "✅ Syntax valid: $file"
    else
        echo "❌ Syntax error in: $file"
        exit 1
    fi
done

# Test package.json scripts
echo "📦 Validating package.json scripts..."
npm run --silent build > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Build script works"
else
    echo "❌ Build script failed"
    exit 1
fi

echo "🎉 All smoke tests passed!"
echo "✅ Build artifacts present"
echo "✅ JavaScript syntax valid"
echo "✅ npm scripts functional"
