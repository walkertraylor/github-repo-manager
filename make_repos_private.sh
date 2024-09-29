#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to change repo visibility
change_repo_visibility() {
    local repo="$1"
    if gh repo edit "$repo" --visibility private 2>/dev/null; then
        echo -e "${GREEN}✅ Changed $repo to private${NC}"
        ((success_count++))
    else
        echo -e "${RED}❌ Failed to change $repo to private${NC}"
        failed_repos+=("$repo")
    fi
}

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI (gh) is not installed. Please install it and try again."
    exit 1
fi

# Main script
echo "This script will change all your public repositories to private."
echo "This action cannot be undone easily. Are you sure you want to proceed? (y/n)"
read -r confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

echo "Changing all public repositories to private..."
echo "This may take a while depending on the number of repositories."

# Get list of public repositories
public_repos=$(gh repo list --json nameWithOwner,visibility --jq '.[] | select(.visibility == "public") | .nameWithOwner')

# Check if there are any public repos
if [ -z "$public_repos" ]; then
    echo "No public repositories found."
    exit 0
fi

# Count of repositories
total_repos=$(echo "$public_repos" | wc -l)
current=0
success_count=0
failed_repos=()

# Loop through repositories and change visibility
echo "$public_repos" | while read -r repo; do
    ((current++))
    percentage=$((current * 100 / total_repos))
    echo -ne "[$percentage%] Processing $repo\r"
    change_repo_visibility "$repo"
done

echo -e "\nFinished processing all repositories."
echo "Summary:"
echo "- Total repositories processed: $total_repos"
echo "- Successfully changed to private: $success_count"
echo "- Failed to change: ${#failed_repos[@]}"

if [ ${#failed_repos[@]} -gt 0 ]; then
    echo "Repositories that failed to change:"
    printf '%s\n' "${failed_repos[@]}"
fi
