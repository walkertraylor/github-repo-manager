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
        return 0
    else
        echo -e "${RED}❌ Failed to change $repo to $visibility${NC}"
        return 1
    fi
}

# Function to get all repositories
get_all_repositories() {
    gh repo list --json nameWithOwner,visibility --jq '.[] | "\(.nameWithOwner)|\(.visibility)"'
}

# Function to display repository selection menu
show_repo_selection_menu() {
    local repos="$1"
    local menu_items=()
    local i=1
    while IFS='|' read -r repo visibility; do
        menu_items+=("$i" "$repo ($visibility)")
        ((i++))
    done <<< "$repos"

    dialog --clear --title "Select Repositories to Toggle Visibility" \
           --checklist "Choose repositories:" 20 70 15 \
           "${menu_items[@]}" 2>&1 >/dev/tty
}

# Function to toggle repository visibility
toggle_repo_visibility() {
    local repo="$1"
    local current_visibility="$2"
    local new_visibility

    if [ "$current_visibility" = "public" ]; then
        new_visibility="private"
    else
        new_visibility="public"
    fi

    if change_repo_visibility "$repo" "$new_visibility"; then
        dialog --msgbox "Successfully changed $repo to $new_visibility" 8 60
    else
        dialog --msgbox "Failed to change $repo to $new_visibility" 8 60
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

# Get all repositories
all_repos=$(get_all_repositories)

# Show repository selection menu
selected_repos=$(show_repo_selection_menu "$all_repos")

# Toggle visibility for selected repositories
for selection in $selected_repos; do
    repo_info=$(echo "$all_repos" | sed -n "${selection}p")
    IFS='|' read -r repo visibility <<< "$repo_info"
    toggle_repo_visibility "$repo" "$visibility"
done

dialog --msgbox "Operation completed." 8 40
