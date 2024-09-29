#!/bin/bash

# Set up logging
LOG_FILE="github_repo_manager.log"
log() {
    echo "$(date): $1" >> "$LOG_FILE"
}

log "Script started"

# Dialog color settings
export DIALOGRC="/tmp/dialogrc"
cat > "$DIALOGRC" << EOF
use_shadow = OFF
use_colors = ON
screen_color = (BLACK,BLACK,OFF)
dialog_color = (CYAN,BLACK,OFF)
title_color = (YELLOW,BLACK,OFF)
border_color = (CYAN,BLACK,OFF)
button_active_color = (BLACK,CYAN,OFF)
button_inactive_color = (CYAN,BLACK,OFF)
button_key_active_color = (BLACK,CYAN,OFF)
button_key_inactive_color = (CYAN,BLACK,OFF)
button_label_active_color = (BLACK,CYAN,OFF)
button_label_inactive_color = (CYAN,BLACK,OFF)
inputbox_color = (CYAN,BLACK,OFF)
inputbox_border_color = (CYAN,BLACK,OFF)
searchbox_color = (CYAN,BLACK,OFF)
searchbox_title_color = (YELLOW,BLACK,OFF)
searchbox_border_color = (CYAN,BLACK,OFF)
position_indicator_color = (YELLOW,BLACK,OFF)
menubox_color = (CYAN,BLACK,OFF)
menubox_border_color = (CYAN,BLACK,OFF)
item_color = (CYAN,BLACK,OFF)
item_selected_color = (BLACK,CYAN,OFF)
tag_color = (YELLOW,BLACK,OFF)
tag_selected_color = (BLACK,YELLOW,OFF)
tag_key_color = (YELLOW,BLACK,OFF)
tag_key_selected_color = (BLACK,YELLOW,OFF)
check_color = (CYAN,BLACK,OFF)
check_selected_color = (BLACK,CYAN,OFF)
uarrow_color = (CYAN,BLACK,OFF)
darrow_color = (CYAN,BLACK,OFF)
EOF

# Colors for terminal output
GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
DARK_GREEN='\033[2;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
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

    log "Checking current visibility of $repo"

    # Get current visibility
    current_visibility=$(gh repo view "$repo" --json visibility --jq '.visibility' 2>&1)
    if [ $? -ne 0 ]; then
        log "Failed to get visibility status for $repo. Error: $current_visibility"
        dialog --title "Error" --msgbox "Failed to get visibility status for $repo.\nError: $current_visibility" 10 60
        return 1
    fi

    current_visibility=$(echo "$current_visibility" | tr '[:upper:]' '[:lower:]')
    log "Current visibility of $repo: $current_visibility"

    # Determine new visibility
    if [ "$current_visibility" = "public" ]; then
        new_visibility="private"
    else
        new_visibility="public"
    fi

    # Change visibility
    log "Changing visibility of $repo from $current_visibility to $new_visibility"
    output=$(gh repo edit "$repo" --visibility "$new_visibility" 2>&1)
    if [ $? -eq 0 ]; then
        log "Successfully changed $repo from $current_visibility to $new_visibility"
        dialog --title "Success" --msgbox "Changed $repo from $current_visibility to $new_visibility" 8 60
        return 0
    else
        log "Failed to change $repo from $current_visibility to $new_visibility. Error: $output"
        
        if echo "$output" | grep -q "API rate limit exceeded"; then
            dialog --title "Error" --msgbox "GitHub API rate limit exceeded. Please try again later." 8 60
        elif echo "$output" | grep -q "Could not resolve to a Repository"; then
            dialog --title "Error" --msgbox "Repository $repo not found or you don't have permission to modify it." 8 60
        elif echo "$output" | grep -q "is archived and cannot be edited"; then
            dialog --title "Error" --msgbox "Repository $repo is archived and cannot be edited.\nPlease unarchive the repository first." 10 60
        else
            dialog --title "Error" --msgbox "Failed to change $repo visibility.\nError: $output" 10 60
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
    gh repo list --json nameWithOwner,visibility,isArchived --limit 1000 --jq '.[] | "\(.nameWithOwner)|\(.visibility)|\(.isArchived)"'
}

# Function to display repository selection menu
show_repo_selection_menu() {
    local repos="$1"
    local menu_items=()
    local i=1
    while IFS='|' read -r repo visibility archived; do
        archived_status=$([ "$archived" = "true" ] && echo "[Archived]" || echo "")
        menu_items+=("$i" "$repo ($visibility) $archived_status" "off")
        ((i++))
    done <<< "$repos"

    dialog --clear --title "Select Repositories to Toggle Visibility" \
           --backtitle "GitHub Repository Visibility Manager" \
           --ok-label "Toggle" \
           --extra-button \
           --extra-label "Back" \
           --no-cancel \
           --checklist "Choose repositories to change visibility:" 25 80 15 \
           "${menu_items[@]}" 2>&1 >/dev/tty
    
    local return_value=$?
    if [ $return_value -eq 3 ]; then
        echo "BACK"
    else
        echo "$REPLY"
    fi
}

# Function to process selected repositories
process_selected_repos() {
    local selected_repos="$1"
    local all_repos="$2"
    local repo
    local visibility
    local archived

    if [ "$selected_repos" = "BACK" ]; then
        return
    fi

    if [ -z "$selected_repos" ]; then
        return
    fi

    for selection in $selected_repos; do
        repo_info=$(echo "$all_repos" | sed -n "${selection}p")
        IFS='|' read -r repo visibility archived <<< "$repo_info"
        if validate_repo_name "$repo"; then
            if [ "$archived" = "true" ]; then
                dialog --msgbox "Repository $repo is archived and cannot be modified." 8 60
            elif toggle_repo_visibility "$repo"; then
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
    local repo_list=$(gh repo list --json nameWithOwner,visibility,isArchived --jq '.[] | "\(.nameWithOwner)|\(.visibility)|\(.isArchived)"')
    
    local formatted_list=""
    while IFS='|' read -r repo visibility archived; do
        archived_status=$([ "$archived" = "true" ] && echo "[Archived]" || echo "")
        formatted_list+="• $repo (Visibility: $visibility)$archived_status\n"
        echo "$(date): $repo | $visibility | $archived_status" >> "$LOG_FILE"
    done <<< "$repo_list"
    
    dialog --title "Repository List" --msgbox "Repositories and their visibility:\n\n$formatted_list" 24 80
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

    log "Saving repository status to $output_file"
    if ! gh repo list --json nameWithOwner,visibility,isArchived --jq '.[] | "\(.nameWithOwner),\(.visibility),\(.isArchived)"' > "$output_file"; then
        log "Failed to save repository status to $output_file"
        dialog --msgbox "Failed to save repository status. Please check your GitHub authentication and try again." 8 60
        return
    fi
    log "Successfully saved repository status to $output_file"
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
    if ! grep -qE '^[^,]+,(public|private),(true|false)$' "$input_file"; then
        dialog --msgbox "Invalid file format. Each line should be 'repo,visibility,isArchived'." 8 60
        return
    fi

    while IFS=',' read -r repo visibility is_archived; do
        if ! validate_repo_name "$repo"; then
            dialog --msgbox "Invalid repository name: $repo. Skipping." 8 60
            continue
        fi
        dialog --yesno "Change $repo to $visibility and archive status to $is_archived?" 8 70
        if [ $? -eq 0 ]; then
            if change_repo_visibility "$repo" "$visibility"; then
                if [ "$is_archived" = "true" ]; then
                    if gh repo edit "$repo" --archived; then
                        dialog --msgbox "Successfully changed $repo to $visibility and archived" 8 60
                    else
                        dialog --msgbox "Changed $repo to $visibility but failed to archive" 8 60
                    fi
                else
                    if gh repo edit "$repo" --unarchived; then
                        dialog --msgbox "Successfully changed $repo to $visibility and unarchived" 8 60
                    else
                        dialog --msgbox "Changed $repo to $visibility but failed to unarchive" 8 60
                    fi
                fi
            else
                dialog --msgbox "Failed to change $repo to $visibility" 8 60
            fi
        fi
    done < "$input_file"

    dialog --msgbox "Finished applying repository status from $input_file" 8 60
}

# Set PAGER to 'cat' to prevent pagination
export PAGER=cat

# Function to search repositories
search_repos() {
    local keyword=$(dialog --inputbox "Enter search keyword:" 8 40 2>&1 >/dev/tty)
    if [ -z "$keyword" ]; then
        return
    fi

    local repos=$(gh repo list --json nameWithOwner,visibility,isArchived --jq ".[] | select(.nameWithOwner | contains(\"$keyword\")) | \"\(.nameWithOwner)|\(.visibility)|\(.isArchived)\"")
    if [ -z "$repos" ]; then
        dialog --msgbox "No repositories found matching the keyword: $keyword" 8 60
        return
    fi

    show_repo_selection_menu "$repos"
}

# Function to display detailed repository information
show_repo_details() {
    local repo="$1"
    local repo_info=$(gh repo view "$repo" --json name,description,url,homepage,defaultBranchRef,isPrivate,isArchived,createdAt,updatedAt,pushedAt,diskUsage,language,licenseInfo,stargazerCount,forkCount,issueCount,pullRequestCount)
    
    local name=$(echo "$repo_info" | jq -r '.name')
    local description=$(echo "$repo_info" | jq -r '.description // "N/A"')
    local url=$(echo "$repo_info" | jq -r '.url')
    local homepage=$(echo "$repo_info" | jq -r '.homepage // "N/A"')
    local default_branch=$(echo "$repo_info" | jq -r '.defaultBranchRef.name')
    local visibility=$(echo "$repo_info" | jq -r 'if .isPrivate then "Private" else "Public" end')
    local archived=$(echo "$repo_info" | jq -r 'if .isArchived then "Yes" else "No" end')
    local created_at=$(echo "$repo_info" | jq -r '.createdAt' | cut -d'T' -f1)
    local updated_at=$(echo "$repo_info" | jq -r '.updatedAt' | cut -d'T' -f1)
    local pushed_at=$(echo "$repo_info" | jq -r '.pushedAt' | cut -d'T' -f1)
    local disk_usage=$(echo "$repo_info" | jq -r '.diskUsage')
    local language=$(echo "$repo_info" | jq -r '.language // "N/A"')
    local license=$(echo "$repo_info" | jq -r '.licenseInfo.name // "N/A"')
    local stars=$(echo "$repo_info" | jq -r '.stargazerCount')
    local forks=$(echo "$repo_info" | jq -r '.forkCount')
    local issues=$(echo "$repo_info" | jq -r '.issueCount')
    local prs=$(echo "$repo_info" | jq -r '.pullRequestCount')

    dialog --title "Repository Details: $repo" --msgbox "\
Name: $name
Description: $description
URL: $url
Homepage: $homepage
Default Branch: $default_branch
Visibility: $visibility
Archived: $archived
Created: $created_at
Last Updated: $updated_at
Last Pushed: $pushed_at
Disk Usage: $disk_usage KB
Primary Language: $language
License: $license
Stars: $stars
Forks: $forks
Open Issues: $issues
Open Pull Requests: $prs" 22 76
}

# Function to display the main menu
show_main_menu() {
    local user_info=$(gh api user --jq '{login: .login, name: .name, public_repos: .public_repos}')
    log "API response: $user_info"
    
    local username=$(echo "$user_info" | jq -r '.login')
    local name=$(echo "$user_info" | jq -r '.name')
    local public_repos=$(echo "$user_info" | jq -r '.public_repos')
    local private_repos=$(gh repo list --json visibility --jq 'map(select(.visibility == "private")) | length')
    
    log "Parsed values: username=$username, name=$name, public_repos=$public_repos, private_repos=$private_repos"
    
    dialog --clear --title "GitHub Repository Manager" \
           --no-cancel \
           --menu "User: $username ($name)\nPublic Repos: $public_repos | Private Repos: $private_repos\n\nChoose an operation:" 22 70 9 \
           1 "List all repositories" \
           2 "Toggle visibility for selected repositories" \
           3 "Save current repository status" \
           4 "Load and apply repository status" \
           5 "Search repositories" \
           6 "Show detailed repository information" \
           7 "Exit" 2>&1 >/dev/tty
}

# Main script
echo "GitHub Repository Visibility Manager"

while true; do
    choice=$(show_main_menu)
    case $choice in
        1)
            all_repos=$(get_all_repositories)
            if check_empty_repo_list "$all_repos"; then
                list_repositories
            fi
            ;;
        2)
            all_repos=$(get_all_repositories)
            if check_empty_repo_list "$all_repos"; then
                selected_repos=$(show_repo_selection_menu "$all_repos")
                process_selected_repos "$selected_repos" "$all_repos"
            fi
            ;;
        3)
            save_repo_status
            ;;
        4)
            load_and_apply_repo_status
            ;;
        5)
            search_repos
            ;;
        6)
            all_repos=$(get_all_repositories)
            if check_empty_repo_list "$all_repos"; then
                repo=$(dialog --menu "Select a repository:" 22 76 16 $(echo "$all_repos" | awk -F'|' '{print NR " " $1}') 2>&1 >/dev/tty)
                if [ -n "$repo" ]; then
                    selected_repo=$(echo "$all_repos" | sed -n "${repo}p" | cut -d'|' -f1)
                    show_repo_details "$selected_repo"
                fi
            fi
            ;;
        7)
            clear
            echo -e "${BRIGHT_GREEN}Exiting...${NC}"
            exit 0
            ;;
        *)
            dialog --msgbox "Invalid option. Please try again." 8 40
            ;;
    esac
done
