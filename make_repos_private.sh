#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to check if a command is available
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if required commands are installed
if ! command_exists gh; then
    echo "GitHub CLI (gh) is not installed. Please install it and try again."
    exit 1
fi

if ! command_exists dialog; then
    echo "The 'dialog' library is not installed. Please install it and try again."
    echo "On Ubuntu/Debian: sudo apt-get install dialog"
    echo "On macOS with Homebrew: brew install dialog"
    exit 1
fi

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

# Set PAGER to 'cat' to prevent pagination
export PAGER=cat

# Function to display the main menu
show_main_menu() {
    dialog --clear --title "GitHub Repository Visibility Manager" \
           --menu "Choose an operation:" 15 60 5 \
           1 "Change all public repositories to private" \
           2 "Change all private repositories to public" \
           3 "List all repositories" \
           4 "Backup repository visibility status" \
           5 "Exit" 2>&1 >/dev/tty
}

# Main script
echo "GitHub Repository Visibility Manager"

# Get total number of repositories
total_repos=$(gh repo list --limit 1000 | wc -l)
echo "Total number of repositories: $total_repos"

# Menu
while true; do
    choice=$(show_main_menu)
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
            echo "Press Enter to continue..."
            read
            continue
            ;;
        4)
            backup_visibility_status
            echo "Press Enter to continue..."
            read
            continue
            ;;
        5)
            clear
            echo "Exiting."
            exit 0
            ;;
        *)
            dialog --msgbox "Invalid choice. Please try again." 8 40
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
