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

# Function to save repository status
save_repo_status() {
    local default_file="repo_status_$(date +%Y%m%d_%H%M%S).csv"
    local output_file=$(dialog --title "Save Repository Status" --inputbox "Enter filename to save status (default: $default_file):" 10 60 "$default_file" 2>&1 >/dev/tty)
    
    if [ $? -ne 0 ]; then
        return
    fi

    echo -e "${YELLOW}Saving repository status to $output_file${NC}"
    gh repo list --json nameWithOwner,visibility --jq '.[] | "\(.nameWithOwner),\(.visibility)"' > "$output_file"
    echo -e "${GREEN}✅ Saved repository status to $output_file${NC}"
    dialog --msgbox "Repository status saved to $output_file" 8 60
}

# Function to load and apply repository status
load_and_apply_repo_status() {
    local default_file=$(ls -t repo_status_*.csv 2>/dev/null | head -n1)
    local input_file=$(dialog --title "Load Repository Status" --inputbox "Enter filename to load status (default: $default_file):" 10 60 "$default_file" 2>&1 >/dev/tty)
    
    if [ $? -ne 0 ] || [ ! -f "$input_file" ]; then
        dialog --msgbox "Invalid file or operation cancelled." 8 40
        return
    fi

    while IFS=',' read -r repo visibility; do
        dialog --yesno "Change $repo to $visibility?" 8 60
        if [ $? -eq 0 ]; then
            if change_repo_visibility "$repo" "$visibility"; then
                dialog --msgbox "Successfully changed $repo to $visibility" 8 60
            else
                dialog --msgbox "Failed to change $repo to $visibility" 8 60
            fi
        fi
    done < "$input_file"

    dialog --msgbox "Finished applying repository status from $input_file" 8 60
}

# Set PAGER to 'cat' to prevent pagination
export PAGER=cat

# Function to display the main menu
show_main_menu() {
    dialog --clear --title "GitHub Repository Visibility Manager" \
           --menu "Choose an operation:" 15 60 7 \
           1 "Toggle visibility for selected repositories" \
           2 "List all repositories" \
           3 "Save current repository status" \
           4 "Load and apply repository status" \
           5 "Exit" 2>&1 >/dev/tty
}

# Main script
echo "GitHub Repository Visibility Manager"

while true; do
    choice=$(show_main_menu)
    case $choice in
        1)
            all_repos=$(get_all_repositories)
            selected_repos=$(show_repo_selection_menu "$all_repos")
            for selection in $selected_repos; do
                repo_info=$(echo "$all_repos" | sed -n "${selection}p")
                IFS='|' read -r repo visibility <<< "$repo_info"
                toggle_repo_visibility "$repo" "$visibility"
            done
            ;;
        2)
            list_repositories | dialog --title "Repository List" --programbox 20 70
            ;;
        3)
            save_repo_status
            ;;
        4)
            load_and_apply_repo_status
            ;;
        5)
            echo "Exiting..."
            exit 0
            ;;
        *)
            dialog --msgbox "Invalid option. Please try again." 8 40
            ;;
    esac
done
