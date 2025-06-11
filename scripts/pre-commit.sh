#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${YELLOW}==>${NC} $1"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to run a command and check its status
run_command() {
    local cmd="$1"
    local name="$2"

    print_status "Running $name..."
    eval "$cmd"
    local status=$?

    if [ $status -ne 0 ]; then
        print_error "$name failed with status $status"
        return 1
    fi

    print_success "$name completed successfully"
    return 0
}

# Check for required tools
print_status "Checking required tools..."
for tool in npm node git; do
    if ! command_exists "$tool"; then
        print_error "$tool is not installed"
        exit 1
    fi
done

# Get the list of staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(js|jsx)$' | tr '\n' ' ')

if [ -z "$STAGED_FILES" ]; then
    print_status "No JavaScript files staged for commit"
    exit 0
fi

# Run type checking
print_status "Running type checking..."
if command_exists "tsc"; then
    run_command "tsc --noEmit" "Type checking"
    if [ $? -ne 0 ]; then
        print_error "Type checking failed"
        exit 1
    fi
fi

# Run linting with auto-fix
print_status "Running ESLint with auto-fix..."
run_command "npm run lint:fix" "ESLint"
if [ $? -ne 0 ]; then
    print_error "Linting failed"
    exit 1
fi

# Run formatting
run_command "npm run format" "Prettier"
if [ $? -ne 0 ]; then
    print_error "Formatting failed"
    exit 1
fi

# Check for security vulnerabilities (only high and critical)
print_status "Checking for high/critical security vulnerabilities..."
AUDIT_RESULT=$(npm audit --audit-level=high 2>&1)
if [[ $AUDIT_RESULT == *"found"* ]]; then
    print_error "High/Critical security vulnerabilities found:"
    echo "$AUDIT_RESULT"
    exit 1
fi

# Check for outdated dependencies
print_status "Checking for outdated dependencies..."
OUTDATED=$(npm outdated)
if [ ! -z "$OUTDATED" ]; then
    print_error "Outdated dependencies found:"
    echo "$OUTDATED"
    exit 1
fi

# Check for console.log statements
print_status "Checking for console.log statements..."
CONSOLE_LOGS=$(grep -r "console.log" --include="*.js" --include="*.jsx" src/)
if [ ! -z "$CONSOLE_LOGS" ]; then
    print_error "console.log statements found:"
    echo "$CONSOLE_LOGS"
    exit 1
fi

# Check for TODO comments
print_status "Checking for TODO comments..."
TODOS=$(grep -r "TODO" --include="*.js" --include="*.jsx" src/)
if [ ! -z "$TODOS" ]; then
    print_error "TODO comments found:"
    echo "$TODOS"
    exit 1
fi

# Check for debugger statements
print_status "Checking for debugger statements..."
DEBUGGERS=$(grep -r "debugger" --include="*.js" --include="*.jsx" src/)
if [ ! -z "$DEBUGGERS" ]; then
    print_error "debugger statements found:"
    echo "$DEBUGGERS"
    exit 1
fi

# Check for large files
print_status "Checking for large files..."
find src -type f -name "*.js" -o -name "*.jsx" | while read file; do
    size=$(wc -l < "$file")
    if [ $size -gt 300 ]; then
        print_error "Large file detected: $file ($size lines)"
        exit 1
    fi
done

# All checks passed
print_success "All pre-commit checks passed!"
exit 0
