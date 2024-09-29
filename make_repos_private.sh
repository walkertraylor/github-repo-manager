#!/bin/bash

# Set up logging
LOG_FILE="repo_visibility_changer.log"
exec >> "$LOG_FILE" 2>&1

echo "Script started at $(date)"

# Dialog color settings
export DIALOGRC="/tmp/dialogrc"
cat > "$DIALOGRC" << EOF
use_shadow = ON
use_colors = ON
screen_color = (WHITE,BLUE,ON)
dialog_color = (BLACK,WHITE,OFF)
title_color = (YELLOW,RED,ON)
border_color = (WHITE,WHITE,ON)
button_active_color = (WHITE,RED,ON)
button_inactive_color = (BLACK,WHITE,OFF)
button_key_active_color = (WHITE,RED,ON)
button_key_inactive_color = (RED,WHITE,OFF)
button_label_active_color = (YELLOW,RED,ON)
button_label_inactive_color = (BLACK,WHITE,ON)
inputbox_color = (BLACK,WHITE,OFF)
inputbox_border_color = (BLACK,WHITE,OFF)
searchbox_color = (BLACK,WHITE,OFF)
searchbox_title_color = (YELLOW,WHITE,ON)
searchbox_border_color = (WHITE,WHITE,ON)
position_indicator_color = (YELLOW,WHITE,ON)
menubox_color = (BLACK,WHITE,OFF)
menubox_border_color = (WHITE,WHITE,ON)
item_color = (BLACK,WHITE,OFF)
item_selected_color = (WHITE,RED,ON)
tag_color = (YELLOW,WHITE,ON)
tag_selected_color = (YELLOW,RED,ON)
tag_key_color = (YELLOW,WHITE,ON)
tag_key_selected_color = (WHITE,RED,ON)
check_color = (BLACK,WHITE,OFF)
check_selected_color = (WHITE,RED,ON)
uarrow_color = (YELLOW,WHITE,ON)
darrow_color = (YELLOW,WHITE,ON)
itemhelp_color = (WHITE,BLACK,OFF)
form_active_text_color = (WHITE,BLUE,ON)
form_text_color = (WHITE,CYAN,ON)
form_item_readonly_color = (CYAN,WHITE,ON)
gauge_color = (BLUE,WHITE,ON)
border2_color = (WHITE,WHITE,ON)
inputbox_border2_color = (BLACK,WHITE,OFF)
searchbox_border2_color = (WHITE,WHITE,ON)
menubox_border2_color = (WHITE,WHITE,ON)
EOF

# Colors for terminal output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
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

# Function to toggle repo visibility
toggle_repo_visibility() {
    local repo="$1"
    local current_visibility
    local new_visibility
    local output

    echo "$(date): Checking current visibility of $repo" >> "$LOG_FILE"

    # Get current visibility
    current_visibility=$(gh repo view "$repo" --json visibility --jq '.visibility' 2>&1)
    if [ $? -ne 0 ]; then
        echo "$(date): Failed to get visibility status for $repo. Error: $current_visibility" >> "$LOG_FILE"
        dialog --title "Error" --msgbox "Failed to get visibility status for $repo." 8 60
        return 1
    fi

    current_visibility=$(echo "$current_visibility" | tr '[:upper:]' '[:lower:]')
    echo "$(date): Current visibility of $repo: $current_visibility" >> "$LOG_FILE"

    # Determine new visibility
    if [ "$current_visibility" = "public" ]; then
        new_visibility="private"
    else
        new_visibility="public"
    fi

    # Change visibility
    echo "$(date): Changing visibility of $repo from $current_visibility to $new_visibility" >> "$LOG_FILE"
    output=$(gh repo edit "$repo" --visibility "$new_visibility" 2>&1)
    if [ $? -eq 0 ]; then
        echo "$(date): Successfully changed $repo from $current_visibility to $new_visibility" >> "$LOG_FILE"
        dialog --title "Success" --msgbox "Changed $repo from $current_visibility to $new_visibility" 8 60
        return 0
    else
        echo "$(date): Failed to change $repo from $current_visibility to $new_visibility. Error: $output" >> "$LOG_FILE"
        
        if echo "$output" | grep -q "API rate limit exceeded"; then
            dialog --title "Error" --msgbox "GitHub API rate limit exceeded. Please try again later." 8 60
        elif echo "$output" | grep -q "Could not resolve to a Repository"; then
            dialog --title "Error" --msgbox "Repository $repo not found or you don't have permission to modify it." 8 60
        else
            dialog --title "Error" --msgbox "Failed to change $repo visibility. Error: $output" 10 60
        fi
        return 1
    fi
}

# Function to validate repository name
validate_repo_name() {
    local repo="$1"
    if [[ $repo =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check for empty repository list
check_empty_repo_list() {
    local repos="$1"
    if [ -z "$repos" ]; then
        dialog --msgbox "No repositories found. Please check your GitHub authentication and try again." 8 60
        return 1
    fi
    return 0
}

# Function to get all repositories
get_all_repositories() {
    gh repo list --json nameWithOwner,visibility --limit 1000 --jq '.[] | "\(.nameWithOwner)|\(.visibility)"'
}

# Function to display repository selection menu
show_repo_selection_menu() {
    local repos="$1"
    local menu_items=()
    local i=1
    while IFS='|' read -r repo visibility; do
        menu_items+=("$i" "$repo ($visibility)" "off")
        ((i++))
    done <<< "$repos"

    dialog --clear --title "Select Repositories to Toggle Visibility" \
           --checklist "Choose repositories to change visibility:" 25 80 15 \
           "${menu_items[@]}" 2>&1 >/dev/tty || echo ""
}

# Function to process selected repositories
process_selected_repos() {
    local selected_repos="$1"
    local all_repos="$2"
    local repo
    local visibility

    for selection in $selected_repos; do
        repo_info=$(echo "$all_repos" | sed -n "${selection}p")
        IFS='|' read -r repo visibility <<< "$repo_info"
        if validate_repo_name "$repo"; then
            if toggle_repo_visibility "$repo"; then
                dialog --msgbox "Successfully toggled visibility for $repo" 8 60
            else
                dialog --msgbox "Failed to toggle visibility for $repo. Check the log file for details." 10 70
            fi
        else
            dialog --msgbox "Invalid repository name: $repo. Skipping." 8 60
        fi
    done
}

# Function to list all repositories
list_repositories() {
    echo "$(date): Listing all repositories" >> "$LOG_FILE"
    local repo_list=$(gh repo list --json nameWithOwner,visibility --jq '.[] | "\(.nameWithOwner) - \(.visibility)"')
    dialog --title "Repository List" --msgbox "$repo_list" 20 80
}

# Function to save repository status
save_repo_status() {
    local default_file="repo_status_$(date +%Y%m%d_%H%M%S).csv"
    local output_file=$(dialog --title "Save Repository Status" --inputbox "Enter filename to save status (default: $default_file):" 10 60 "$default_file" 2>&1 >/dev/tty)
    
    if [ $? -ne 0 ] || [ -z "$output_file" ]; then
        dialog --msgbox "Operation cancelled or empty filename provided." 8 60
        return
    fi

    # Validate filename
    if [[ ! $output_file =~ ^[a-zA-Z0-9_.-]+\.csv$ ]]; then
        dialog --msgbox "Invalid filename. Please use only letters, numbers, underscores, hyphens, and periods, and end with .csv" 8 60
        return
    fi

    # Ensure the directory exists
    mkdir -p "$(dirname "$output_file")"

    echo "$(date): Saving repository status to $output_file" >> "$LOG_FILE"
    if ! gh repo list --json nameWithOwner,visibility --jq '.[] | "\(.nameWithOwner),\(.visibility)"' > "$output_file"; then
        echo "$(date): Failed to save repository status to $output_file" >> "$LOG_FILE"
        dialog --msgbox "Failed to save repository status. Please check your GitHub authentication and try again." 8 60
        return
    fi
    echo "$(date): Successfully saved repository status to $output_file" >> "$LOG_FILE"
    dialog --msgbox "Repository status saved to $output_file" 8 60
}

# Function to load and apply repository status
load_and_apply_repo_status() {
    local default_file=$(ls -t repo_status_*.csv 2>/dev/null | head -n1)
    local input_file=$(dialog --title "Load Repository Status" --inputbox "Enter filename to load status (default: $default_file):" 10 60 "$default_file" 2>&1 >/dev/tty)
    
    if [ $? -ne 0 ] || [ -z "$input_file" ]; then
        dialog --msgbox "Operation cancelled or empty filename provided." 8 60
        return
    fi

    if [ ! -f "$input_file" ]; then
        dialog --msgbox "File not found: $input_file" 8 40
        return
    fi

    # Check if the file is readable
    if [ ! -r "$input_file" ]; then
        dialog --msgbox "Cannot read file: $input_file. Please check permissions." 8 60
        return
    fi

    # Validate file content
    if ! grep -qE '^[^,]+,(public|private)$' "$input_file"; then
        dialog --msgbox "Invalid file format. Each line should be 'repo,visibility'." 8 60
        return
    fi

    while IFS=',' read -r repo visibility; do
        if ! validate_repo_name "$repo"; then
            dialog --msgbox "Invalid repository name: $repo. Skipping." 8 60
            continue
        fi
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
           --menu "Choose an operation:" 20 70 7 \
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
            if check_empty_repo_list "$all_repos"; then
                selected_repos=$(show_repo_selection_menu "$all_repos")
                if [ -n "$selected_repos" ]; then
                    process_selected_repos "$selected_repos" "$all_repos"
                else
                    dialog --msgbox "No repositories selected." 8 40
                fi
            fi
            ;;
        2)
            all_repos=$(get_all_repositories)
            if check_empty_repo_list "$all_repos"; then
                clear
                echo "Repository List:"
                echo "$all_repos" | column -t -s '|'
                read -p "Press Enter to continue..."
            fi
            ;;
        3)
            save_repo_status
            ;;
        4)
            load_and_apply_repo_status
            ;;
        5)
            clear
            echo "Exiting..."
            exit 0
            ;;
        *)
            dialog --msgbox "Invalid option. Please try again." 8 40
            ;;
    esac
done
