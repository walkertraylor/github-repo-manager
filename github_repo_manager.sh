#!/bin/bash

# GitHub Repository Manager
# Version 1.0

# Set up logging
LOG_FILE="github_repo_manager.log"
log() {
    echo "$(date): $1" >> "$LOG_FILE"
}

log "Script started (Version 1.0)"

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

    # Get current visibility using GitHub CLI
    current_visibility=$(gh repo view "$repo" --json visibility --jq '.visibility' 2>&1)
    if [ $? -ne 0 ]; then
        log "Failed to get visibility status for $repo. Error: $current_visibility"
        dialog --title "Error" --msgbox "Failed to get visibility status for $repo.\nError: $current_visibility" 10 60
        return 1
    fi

    current_visibility=$(echo "$current_visibility" | tr '[:upper:]' '[:lower:]')
    log "Current visibility of $repo: $current_visibility"

    # Determine new visibility (toggle between public and private)
    if [ "$current_visibility" = "public" ]; then
        new_visibility="private"
    else
        new_visibility="public"
    fi

    # Attempt to change visibility using GitHub CLI
    log "Attempting to change visibility of $repo from $current_visibility to $new_visibility"
    output=$(gh repo edit "$repo" --visibility "$new_visibility" 2>&1)
    if [ $? -eq 0 ]; then
        log "Successfully changed $repo from $current_visibility to $new_visibility"
        dialog --title "Success" --msgbox "Changed $repo from $current_visibility to $new_visibility" 8 60
        return 0
    else
        log "Failed to change $repo from $current_visibility to $new_visibility. Error: $output"
        
        # Handle specific error cases
        if echo "$output" | grep -q "API rate limit exceeded"; then
            log "Error: GitHub API rate limit exceeded"
            dialog --title "Error" --msgbox "GitHub API rate limit exceeded. Please try again later." 8 60
        elif echo "$output" | grep -q "Could not resolve to a Repository"; then
            log "Error: Repository $repo not found or no permission to modify"
            dialog --title "Error" --msgbox "Repository $repo not found or you don't have permission to modify it." 8 60
        elif echo "$output" | grep -q "is archived and cannot be edited"; then
            log "Error: Repository $repo is archived and cannot be edited"
            dialog --title "Error" --msgbox "Repository $repo is archived and cannot be edited.\nPlease unarchive the repository first." 10 60
        else
            log "Unhandled error occurred: $output"
            dialog --title "Error" --msgbox "Failed to change $repo visibility.\nError: $output" 10 60
        fi
        return 1
    fi
}

# Function to toggle repo archive status
toggle_repo_archive_status() {
    local repo="$1"
    local current_status
    local new_status
    local output

    log "Starting toggle_repo_archive_status for $repo"

    log "Checking current archive status of $repo"
    # Get current archive status using GitHub CLI
    current_status=$(gh repo view "$repo" --json isArchived --jq '.isArchived' 2>&1)
    if [ $? -ne 0 ]; then
        log "Failed to get archive status for $repo. Error: $current_status"
        dialog --title "Error" --msgbox "Failed to get archive status for $repo.\nError: $current_status" 10 60
        return 1
    fi

    log "Current archive status of $repo: $current_status"

    # Determine new status (toggle between archived and unarchived)
    if [ "$current_status" = "true" ]; then
        new_status="unarchived"
        archive_flag="false"
    else
        new_status="archived"
        archive_flag="true"
    fi
    log "New status will be: $new_status (archive_flag: $archive_flag)"

    # Confirmation dialog
    log "Preparing to show confirmation dialog"
    sleep 1  # Add a small delay before showing the dialog
    log "Showing confirmation dialog"
    dialog --stdout --title "Confirm Archive Status Change" --yesno "Are you sure you want to change $repo to $new_status?" 8 60
    local dialog_result=$?
    log "Dialog result: $dialog_result"
    if [ $dialog_result -ne 0 ]; then
        log "User cancelled archive status change for $repo"
        dialog --title "Cancelled" --msgbox "Archive status change cancelled for $repo" 8 60
        return 2
    fi

    # Attempt to change archive status using GitHub CLI
    log "Attempting to change archive status of $repo from $current_status to $new_status"
    output=$(gh repo edit "$repo" --archived="$archive_flag" 2>&1)
    local gh_result=$?
    log "GitHub CLI command result: $gh_result"
    log "GitHub CLI output: $output"
    
    if [ $gh_result -eq 0 ]; then
        log "Successfully changed $repo to $new_status"
        dialog --title "Success" --msgbox "Changed $repo to $new_status" 8 60
        return 0
    else
        log "Failed to change $repo to $new_status. Error: $output"
        
        # Handle specific error cases
        if echo "$output" | grep -q "API rate limit exceeded"; then
            log "Error: GitHub API rate limit exceeded"
            dialog --title "Error" --msgbox "GitHub API rate limit exceeded. Please try again later." 8 60
        elif echo "$output" | grep -q "Could not resolve to a Repository"; then
            log "Error: Repository $repo not found or no permission to modify"
            dialog --title "Error" --msgbox "Repository $repo not found or you don't have permission to modify it." 8 60
        elif echo "$output" | grep -q "Resource not accessible by integration"; then
            log "Error: No permission to archive/unarchive repository $repo"
            dialog --title "Error" --msgbox "You don't have permission to archive/unarchive this repository." 8 60
        else
            log "Unhandled error occurred: $output"
            dialog --title "Error" --msgbox "Failed to change $repo archive status.\nError: $output" 10 60
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

# Global variable to store cached repository list
CACHED_REPOS=""

# Function to get all repositories
get_all_repositories() {
    # If the cache is empty, fetch repositories from GitHub CLI
    if [ -z "$CACHED_REPOS" ]; then
        CACHED_REPOS=$(gh repo list --json nameWithOwner,visibility,isArchived --limit 1000 --jq '.[] | "\(.nameWithOwner)|\(.visibility)|\(.isArchived)"')
    fi
    echo "$CACHED_REPOS"
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

    IFS=$'\n' read -d '' -r -a repo_array <<< "$all_repos"
    for selection in $selected_repos; do
        if [[ $selection =~ ^[0-9]+$ ]] && [ "$selection" -le "${#repo_array[@]}" ]; then
            repo_info="${repo_array[$((selection-1))]}"
            IFS='|' read -r repo visibility archived <<< "$repo_info"
            if [ "$archived" = "true" ]; then
                dialog --msgbox "Repository $repo is archived and cannot be modified." 8 60
            elif toggle_repo_visibility "$repo"; then
                dialog --msgbox "Successfully toggled visibility for $repo" 8 60
            else
                dialog --msgbox "Failed to toggle visibility for $repo. Check the log file for details." 10 70
            fi
        fi
    done
}

# Function to process selected repositories for archive status toggling
process_selected_repos_archive() {
    local selected_repos="$1"
    local all_repos="$2"
    local repo
    local visibility
    local archived
    local refresh_needed=false

    if [ "$selected_repos" = "BACK" ]; then
        return
    fi

    if [ -z "$selected_repos" ]; then
        return
    fi

    IFS=$'\n' read -d '' -r -a repo_array <<< "$all_repos"
    for selection in $selected_repos; do
        if [[ $selection =~ ^[0-9]+$ ]] && [ "$selection" -le "${#repo_array[@]}" ]; then
            repo_info="${repo_array[$((selection-1))]}"
            IFS='|' read -r repo visibility archived <<< "$repo_info"
            toggle_result=$(toggle_repo_archive_status "$repo")
            case $toggle_result in
                0)
                    dialog --msgbox "Successfully toggled archive status for $repo" 8 60
                    refresh_needed=true
                    ;;
                1)
                    dialog --msgbox "Failed to toggle archive status for $repo. Check the log file for details." 10 70
                    ;;
                2)
                    dialog --msgbox "Archive status change cancelled for $repo" 8 60
                    ;;
            esac
        fi
    done

    if [ "$refresh_needed" = true ]; then
        CACHED_REPOS=""
        get_all_repositories >/dev/null
        dialog --msgbox "Repository cache has been refreshed." 8 40
    fi
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
        log "Operation cancelled or empty filename provided for saving repository status"
        dialog --msgbox "Operation cancelled or empty filename provided." 8 60
        return
    fi

    # Validate filename
    if [[ ! $output_file =~ ^[a-zA-Z0-9_.-]+\.csv$ ]]; then
        log "Invalid filename provided: $output_file"
        dialog --msgbox "Invalid filename. Please use only letters, numbers, underscores, hyphens, and periods, and end with .csv" 8 60
        return
    fi

    # Ensure the directory exists
    mkdir -p "$(dirname "$output_file")"

    log "Attempting to save repository status to $output_file"
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
        log "Operation cancelled or empty filename provided for loading repository status"
        dialog --msgbox "Operation cancelled or empty filename provided." 8 60
        return
    fi

    if [ ! -f "$input_file" ]; then
        log "File not found: $input_file"
        dialog --msgbox "File not found: $input_file" 8 40
        return
    fi

    # Check if the file is readable
    if [ ! -r "$input_file" ]; then
        log "Cannot read file: $input_file. Please check permissions."
        dialog --msgbox "Cannot read file: $input_file. Please check permissions." 8 60
        return
    fi

    # Validate file content
    if ! grep -qE '^[^,]+,(public|private),(true|false)$' "$input_file"; then
        log "Invalid file format in $input_file"
        dialog --msgbox "Invalid file format. Each line should be 'repo,visibility,isArchived'." 8 60
        return
    fi

    log "Starting to apply repository status from $input_file"
    while IFS=',' read -r repo visibility is_archived; do
        if ! validate_repo_name "$repo"; then
            log "Invalid repository name: $repo. Skipping."
            dialog --msgbox "Invalid repository name: $repo. Skipping." 8 60
            continue
        fi
        dialog --yesno "Change $repo to $visibility and archive status to $is_archived?" 8 70
        if [ $? -eq 0 ]; then
            log "Attempting to change $repo to $visibility and archive status to $is_archived"
            if change_repo_visibility "$repo" "$visibility"; then
                if [ "$is_archived" = "true" ]; then
                    if gh repo edit "$repo" --archived; then
                        log "Successfully changed $repo to $visibility and archived"
                        dialog --msgbox "Successfully changed $repo to $visibility and archived" 8 60
                    else
                        log "Changed $repo to $visibility but failed to archive"
                        dialog --msgbox "Changed $repo to $visibility but failed to archive" 8 60
                    fi
                else
                    if gh repo edit "$repo" --unarchived; then
                        log "Successfully changed $repo to $visibility and unarchived"
                        dialog --msgbox "Successfully changed $repo to $visibility and unarchived" 8 60
                    else
                        log "Changed $repo to $visibility but failed to unarchive"
                        dialog --msgbox "Changed $repo to $visibility but failed to unarchive" 8 60
                    fi
                fi
            else
                log "Failed to change $repo to $visibility"
                dialog --msgbox "Failed to change $repo to $visibility" 8 60
            fi
        else
            log "User skipped changing $repo"
        fi
    done < "$input_file"

    log "Finished applying repository status from $input_file"
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
    local repo_info
    local error_message

    log "Fetching repository information for $repo"
    repo_info=$(gh repo view "$repo" --json name,description,url,homepageUrl,defaultBranchRef,isPrivate,isArchived,createdAt,updatedAt,pushedAt,diskUsage,languages,licenseInfo,stargazerCount,forkCount,issues,pullRequests 2>&1)
    if [ $? -ne 0 ]; then
        error_message="Failed to fetch repository information for $repo. Error: $repo_info"
        log "$error_message"
        dialog --title "Error" --msgbox "$error_message" 10 60
        return
    fi

    if [ -z "$repo_info" ]; then
        error_message="No information retrieved for repository $repo"
        log "$error_message"
        dialog --title "Error" --msgbox "$error_message" 8 60
        return
    fi

    log "Successfully fetched repository information for $repo"
    log "Raw repository info: $repo_info"

    local name=$(echo "$repo_info" | jq -r '.name // "N/A"')
    local description=$(echo "$repo_info" | jq -r '.description // "N/A"')
    local url=$(echo "$repo_info" | jq -r '.url // "N/A"')
    local homepage=$(echo "$repo_info" | jq -r '.homepageUrl // "N/A"')
    local default_branch=$(echo "$repo_info" | jq -r '.defaultBranchRef.name // "N/A"')
    local visibility=$(echo "$repo_info" | jq -r 'if .isPrivate then "Private" else "Public" end')
    local archived=$(echo "$repo_info" | jq -r 'if .isArchived then "Yes" else "No" end')
    local created_at=$(echo "$repo_info" | jq -r '.createdAt // "N/A"' | cut -d'T' -f1)
    local updated_at=$(echo "$repo_info" | jq -r '.updatedAt // "N/A"' | cut -d'T' -f1)
    local pushed_at=$(echo "$repo_info" | jq -r '.pushedAt // "N/A"' | cut -d'T' -f1)
    local disk_usage=$(echo "$repo_info" | jq -r '.diskUsage // "N/A"')
    local language=$(echo "$repo_info" | jq -r '(.languages | keys)[0] // "N/A"')
    local license=$(echo "$repo_info" | jq -r '.licenseInfo.name // "N/A"')
    local stars=$(echo "$repo_info" | jq -r '.stargazerCount // "N/A"')
    local forks=$(echo "$repo_info" | jq -r '.forkCount // "N/A"')
    local issues=$(echo "$repo_info" | jq -r '.issues.totalCount // "N/A"')
    local prs=$(echo "$repo_info" | jq -r '.pullRequests.totalCount // "N/A"')

    local details="
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
Open Pull Requests: $prs"

    log "Formatted repository details for $repo: $details"
    dialog --title "Repository Details: $repo" --msgbox "$details" 22 76
}

# Function to display the main menu
show_main_menu() {
    local refresh_cache=$1
    # Refresh the cache if needed
    if [ "$refresh_cache" = "true" ] || [ -z "$CACHED_REPOS" ]; then
        CACHED_REPOS=""
        get_all_repositories >/dev/null
    fi

    # Fetch user information from GitHub API
    local user_info=$(gh api user --jq '{login: .login, name: .name, public_repos: .public_repos}')
    log "API response: $user_info"
    
    # Parse user information
    local username=$(echo "$user_info" | jq -r '.login')
    local name=$(echo "$user_info" | jq -r '.name')
    local public_repos=$(echo "$user_info" | jq -r '.public_repos')
    local total_repos=$(echo "$CACHED_REPOS" | wc -l)
    local private_repos=$((total_repos - public_repos))
    
    log "Parsed values: username=$username, name=$name, public_repos=$public_repos, private_repos=$private_repos, total_repos=$total_repos"
    
    # Display the main menu using dialog
    dialog --clear --title "GitHub Repository Manager" \
           --no-cancel \
           --menu "User: $username ($name)\nPublic Repos: $public_repos | Private Repos: $private_repos\n\nChoose an operation:" 23 70 10 \
           1 "List all repositories" \
           2 "Toggle visibility for selected repositories" \
           3 "Toggle archive status for selected repositories" \
           4 "Save current repository status" \
           5 "Load and apply repository status" \
           6 "Search repositories" \
           7 "Show detailed repository information" \
           8 "Refresh repository cache" \
           9 "Exit" 2>&1 >/dev/tty
}

# Main script
echo "GitHub Repository Manager"

refresh_cache=false
while true; do
    choice=$(show_main_menu "$refresh_cache")
    refresh_cache=false
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
                if [ "$selected_repos" != "BACK" ]; then
                    process_selected_repos "$selected_repos" "$all_repos"
                    refresh_cache=true
                fi
            fi
            ;;
        3)
            all_repos=$(get_all_repositories)
            if check_empty_repo_list "$all_repos"; then
                selected_repos=$(show_repo_selection_menu "$all_repos")
                if [ "$selected_repos" != "BACK" ]; then
                    process_selected_repos_archive "$selected_repos" "$all_repos"
                    refresh_cache=true
                fi
            fi
            ;;
        4)
            save_repo_status
            ;;
        5)
            load_and_apply_repo_status
            refresh_cache=true
            ;;
        6)
            search_repos
            ;;
        7)
            all_repos=$(get_all_repositories)
            if check_empty_repo_list "$all_repos"; then
                repo=$(dialog --menu "Select a repository:" 22 76 16 $(echo "$all_repos" | awk -F'|' '{print NR " " $1}') 2>&1 >/dev/tty)
                if [ -n "$repo" ]; then
                    selected_repo=$(echo "$all_repos" | sed -n "${repo}p" | cut -d'|' -f1)
                    show_repo_details "$selected_repo"
                fi
            fi
            ;;
        8)
            refresh_cache=true
            ;;
        9)
            clear
            echo -e "${BRIGHT_GREEN}Exiting...${NC}"
            exit 0
            ;;
        *)
            dialog --msgbox "Invalid option. Please try again." 8 40
            ;;
    esac
done
