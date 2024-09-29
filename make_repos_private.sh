#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to change repo visibility
change_repo_visibility() {
    local repo="$1"
    local visibility="$2"
    if gh repo edit "$repo" --visibility "$visibility" 2>/dev/null; then
        echo -e "${GREEN}✅ Changed $repo to $visibility${NC}"
        ((success_count++))
    else
        echo -e "${RED}❌ Failed to change $repo to $visibility${NC}"
        failed_repos+=("$repo")
    fi
}

# Function to list all repositories
list_repositories() {
    echo -e "${YELLOW}Listing all repositories:${NC}"
    gh repo list --json nameWithOwner,visibility --jq '.[] | "\(.nameWithOwner) - \(.visibility)"'
}

# Function to export repository visibility status
export_visibility_status() {
    local output_file="$1"
    echo -e "${YELLOW}Exporting repository visibility status to $output_file${NC}"
    gh repo list --json nameWithOwner,visibility --jq '.[] | "\(.nameWithOwner),\(.visibility)"' > "$output_file"
    echo -e "${GREEN}✅ Exported repository visibility status to $output_file${NC}"
}

# Function to backup repository visibility status
backup_visibility_status() {
    local backup_file="visibility_backup_$(date +%Y%m%d_%H%M%S).csv"
    echo -e "${YELLOW}Backing up repository visibility status to $backup_file${NC}"
    export_visibility_status "$backup_file"
    echo -e "${GREEN}✅ Backed up repository visibility status to $backup_file${NC}"
}

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI (gh) is not installed. Please install it and try again."
    exit 1
fi

# Set PAGER to 'cat' to prevent pagination
export PAGER=cat

# Main script
echo "GitHub Repository Visibility Manager"

# Get total number of repositories
total_repos=$(gh repo list --limit 1000 | wc -l)
echo "Total number of repositories: $total_repos"

# Menu
while true; do
    echo -e "\nWhat would you like to do?"
    echo "1. Change all public repositories to private"
    echo "2. Change all private repositories to public"
    echo "3. List all repositories"
    echo "4. Backup repository visibility status"
    echo "5. Exit"
    read -p "Enter your choice (1-5): " choice

    case $choice in
        1)
            target_visibility="private"
            source_visibility="public"
            break
            ;;
        2)
            target_visibility="public"
            source_visibility="private"
            break
            ;;
        3)
            list_repositories
            continue
            ;;
        4)
            backup_visibility_status
            continue
            ;;
        5)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            continue
            ;;
    esac
done

echo "This action will change all $source_visibility repositories to $target_visibility."
echo "This action cannot be undone easily. Are you sure you want to proceed? (y/n)"
read -r confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

echo "Changing $source_visibility repositories to $target_visibility..."
echo "This may take a while depending on the number of repositories."

# Backup current visibility status
backup_visibility_status

# Get list of repositories to change
repos_to_change=$(gh repo list --json nameWithOwner,visibility --jq ".[] | select(.visibility == \"$source_visibility\") | .nameWithOwner")

# Debug output
echo "Debug: Repositories to change:"
echo "$repos_to_change"
echo "Debug: End of repositories list"

# Check if there are any repos to change
if [ -z "$repos_to_change" ]; then
    echo "No $source_visibility repositories found. No changes were made."
    exit 0
fi

# Count of repositories
total_to_change=$(echo "$repos_to_change" | wc -l)
current=0
success_count=0
failed_repos=()

# Loop through repositories and change visibility
echo "$repos_to_change" | while IFS= read -r repo; do
    ((current++))
    percentage=$((current * 100 / total_to_change))
    echo -ne "[$percentage%] Processing $repo\r"
    change_repo_visibility "$repo" "$target_visibility"
done

echo -e "\nFinished processing all repositories."
echo "Summary:"
echo "- Total repositories processed: $total_to_change"
echo "- Successfully changed to $target_visibility: $success_count"
echo "- Failed to change: ${#failed_repos[@]}"

if [ ${#failed_repos[@]} -gt 0 ]; then
    echo "Repositories that failed to change:"
    printf '%s\n' "${failed_repos[@]}"
fi

echo -e "\nA backup of the original visibility status has been created."
