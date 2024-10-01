#!/bin/bash

# GitHub Repository Manager
# A tool to manage GitHub repositories, including visibility and archive status
#
# This script provides a menu-driven interface to manage GitHub repositories,
# allowing users to toggle visibility, archive status, and perform other
# repository management tasks.
#
# Features:
# - List all repositories
# - Toggle visibility for selected repositories
# - Toggle archive status for selected repositories
# - Save and load repository status
# - Search repositories
# - Show detailed repository information
#
# Requirements:
# - GitHub CLI (gh) must be installed and authenticated
# - jq must be installed for JSON parsing
# - dialog must be installed for the interactive menu interface
#
# Usage: ./github_repo_manager.sh

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
check_required_commands() {
    local missing_commands=()

    if ! command_exists gh; then
        missing_commands+=("GitHub CLI (gh)")
    fi

    if ! command_exists dialog; then
        missing_commands+=("dialog")
    fi

    if ! command_exists jq; then
        missing_commands+=("jq")
    fi

    if [ ${#missing_commands[@]} -ne 0 ]; then
        echo "Error: The following required commands are not installed:"
        for cmd in "${missing_commands[@]}"; do
            echo "- $cmd"
        done
        echo "Please install the missing commands and try again."
        echo "Installation instructions:"
        echo "- GitHub CLI: https://cli.github.com/"
        echo "- dialog: Use your system's package manager (e.g., apt-get install dialog)"
        echo "- jq: Use your system's package manager (e.g., apt-get install jq)"
        exit 1
    fi
}

# Run the check for required commands
check_required_commands

# Function to toggle repo visibility
toggle_repo_visibility() {
    local repo="$1"
    local current_visibility
    local new_visibility
    local output

    log "Checking current visibility of $repo"

    # Get current visibility using GitHub CLI
    if ! current_visibility=$(gh repo view "$repo" --json visibility --jq '.visibility' 2>&1 | tr '[:upper:]' '[:lower:]'); then
        log "Failed to get visibility status for $repo. Error: $current_visibility"
        dialog --title "Error" --msgbox "Failed to get visibility status for $repo.\nError: $current_visibility" $(calculate_dialog_size)
        return 1
    fi

    log "Current visibility of $repo: $current_visibility"

    # Determine new visibility (toggle between public and private)
    new_visibility=$([ "$current_visibility" = "public" ] && echo "private" || echo "public")

    # Attempt to change visibility using GitHub CLI
    log "Attempting to change visibility of $repo from $current_visibility to $new_visibility"
    if output=$(gh repo edit "$repo" --visibility "$new_visibility" 2>&1); then
        log "Successfully changed $repo from $current_visibility to $new_visibility"
        dialog --title "Success" --msgbox "Changed $repo from $current_visibility to $new_visibility" $(calculate_dialog_size)
        return 0
    else
        log "Failed to change $repo from $current_visibility to $new_visibility. Error: $output"
        
        # Handle specific error cases
        case "$output" in
            *"API rate limit exceeded"*)
                log "Error: GitHub API rate limit exceeded"
                dialog --title "Error" --msgbox "GitHub API rate limit exceeded. Please try again later." $(calculate_dialog_size)
                ;;
            *"Could not resolve to a Repository"*)
                log "Error: Repository $repo not found or no permission to modify"
                dialog --title "Error" --msgbox "Repository $repo not found or you don't have permission to modify it." $(calculate_dialog_size)
                ;;
            *"is archived and cannot be edited"*)
                log "Error: Repository $repo is archived and cannot be edited"
                dialog --title "Error" --msgbox "Repository $repo is archived and cannot be edited.\nPlease unarchive the repository first." $(calculate_dialog_size)
                ;;
            *)
                log "Unhandled error occurred: $output"
                dialog --title "Error" --msgbox "Failed to change $repo visibility.\nError: $output" $(calculate_dialog_size)
                ;;
        esac
        return 1
    fi
}

# Function to toggle repo archive status
toggle_repo_archive_status() {
    local repo="$1"
    local current_status
    local new_status
    local archive_action
    local output

    log "Starting toggle_repo_archive_status for $repo"

    log "Checking current archive status of $repo"
    if ! current_status=$(gh repo view "$repo" --json isArchived --jq '.isArchived' 2>&1); then
        log "Failed to get archive status for $repo. Error: $current_status"
        return 1
    fi
    log "Current archive status of $repo: $current_status"

    # Determine new status and action
    if [ "$current_status" = "true" ]; then
        new_status="unarchived"
        archive_action="unarchive"
    else
        new_status="archived"
        archive_action="archive"
    fi
    log "New status will be: $new_status (archive_action: $archive_action)"

    log "Attempting to change archive status of $repo from $current_status to $new_status"
    log "Executing command: gh repo $archive_action \"$repo\" --yes"
    if output=$(gh repo $archive_action "$repo" --yes 2>&1); then
        log "Successfully changed $repo to $new_status"
        log "Repository status change successful. Refreshing cache..."
        CACHED_REPOS=""
        get_all_repositories >/dev/null
        log "Cache refreshed"
        return 0
    else
        log "Failed to change $repo to $new_status. Error: $output"
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
        dialog --msgbox "No repositories found. Please check your GitHub authentication and try again." $(calculate_dialog_size)
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
        log "Fetching repositories from GitHub CLI"
        CACHED_REPOS=$(gh repo list --json nameWithOwner,visibility,isArchived --limit 1000 --jq '.[] | "\(.nameWithOwner)|\(.visibility)|\(.isArchived)"' 2>&1)
        if [ $? -ne 0 ]; then
            log "Error fetching repositories: $CACHED_REPOS"
            dialog --title "Error" $(calculate_dialog_size) --msgbox "Failed to fetch repositories from GitHub. Error: $CACHED_REPOS"
            return 1
        fi
        if [ -z "$CACHED_REPOS" ]; then
            log "No repositories found or empty response from GitHub CLI"
            dialog --title "Warning" $(calculate_dialog_size) --msgbox "No repositories found or empty response from GitHub CLI. Please check your GitHub authentication and permissions."
            return 1
        fi
        log "Successfully fetched repositories"
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

    dialog --clear --title "Select Repositories to Toggle Archive Status" \
           --backtitle "GitHub Repository Manager" \
           --ok-label "Toggle" \
           --extra-button \
           --extra-label "Back" \
           --no-cancel \
           --checklist "Choose repositories to change archive status:" $(calculate_dialog_size) \
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
                dialog $(calculate_dialog_size) --msgbox "Repository $repo is archived and cannot be modified."
            else
                dialog --title "Confirm Visibility Change" --yesno "Are you sure you want to change the visibility of $repo?" $(calculate_dialog_size)
                if [ $? -eq 0 ]; then
                    if toggle_repo_visibility "$repo"; then
                        dialog --msgbox "Successfully toggled visibility for $repo" $(calculate_dialog_size)
                    else
                        dialog --msgbox "Failed to toggle visibility for $repo. Check the log file for details." $(calculate_dialog_size)
                    fi
                else
                    dialog --msgbox "Visibility change cancelled for $repo" $(calculate_dialog_size)
                fi
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
            
            dialog --title "Confirm Archive Status Change" --yesno "Are you sure you want to change the archive status of $repo?" $(calculate_dialog_size)
            if [ $? -eq 0 ]; then
                log "Attempting to change archive status of $repo"
                if toggle_repo_archive_status "$repo"; then
                    dialog --msgbox "Successfully changed archive status for $repo" $(calculate_dialog_size)
                    refresh_needed=true
                else
                    dialog --msgbox "Failed to change archive status for $repo. Check the log file for details." $(calculate_dialog_size)
                fi
            else
                dialog --msgbox "Archive status change cancelled for $repo" $(calculate_dialog_size)
            fi
        fi
    done

    if [ "$refresh_needed" = true ]; then
        CACHED_REPOS=""
        get_all_repositories >/dev/null
        dialog --msgbox "Repository cache has been refreshed." $(calculate_dialog_size)
    fi
}

# Function to list all repositories
list_repositories() {
    echo "$(date): Listing all repositories" >> "$LOG_FILE"
    local repo_list
    repo_list=$(gh repo list --json nameWithOwner,visibility,isArchived --jq '.[] | "\(.nameWithOwner)|\(.visibility)|\(.isArchived)"' 2>&1)
    
    if [ $? -ne 0 ]; then
        log "Error fetching repository list: $repo_list"
        dialog --title "Error" --msgbox "Failed to fetch repository list. Error: $repo_list" $(calculate_dialog_size)
        return 1
    fi
    
    if [ -z "$repo_list" ]; then
        log "No repositories found or empty response from GitHub CLI"
        dialog --title "Warning" --msgbox "No repositories found or empty response from GitHub CLI. Please check your GitHub authentication and permissions." $(calculate_dialog_size)
        return 1
    fi
    
    local formatted_list=""
    while IFS='|' read -r repo visibility archived; do
        archived_status=$([ "$archived" = "true" ] && echo "[Archived]" || echo "")
        formatted_list+="• $repo (Visibility: $visibility)$archived_status\n"
        echo "$(date): $repo | $visibility | $archived_status" >> "$LOG_FILE"
    done <<< "$repo_list"
    
    dialog --title "Repository List" --msgbox "Repositories and their visibility:\n\n$formatted_list" $(calculate_dialog_size)
}

# Function to save repository status
save_repo_status() {
    local default_file="repo_status_$(date +%Y%m%d_%H%M%S).csv"
    local output_file=$(dialog --title "Save Repository Status" --inputbox "Enter filename to save status (default: $default_file):" 10 60 "$default_file" 2>&1 >/dev/tty)
    
    if [ $? -ne 0 ] || [ -z "$output_file" ]; then
        log "Operation cancelled or empty filename provided for saving repository status"
        dialog --msgbox "Operation cancelled or empty filename provided." $(calculate_dialog_size)
        return
    fi

    # Validate filename
    if [[ ! $output_file =~ ^[a-zA-Z0-9_.-]+\.csv$ ]]; then
        log "Invalid filename provided: $output_file"
        dialog --msgbox "Invalid filename. Please use only letters, numbers, underscores, hyphens, and periods, and end with .csv" $(calculate_dialog_size)
        return
    fi

    # Ensure the directory exists
    mkdir -p "$(dirname "$output_file")"

    log "Attempting to save repository status to $output_file"
    if ! gh repo list --json nameWithOwner,visibility,isArchived --jq '.[] | "\(.nameWithOwner),\(.visibility),\(.isArchived)"' > "$output_file"; then
        log "Failed to save repository status to $output_file"
        dialog --msgbox "Failed to save repository status. Please check your GitHub authentication and try again." $(calculate_dialog_size)
        return
    fi
    log "Successfully saved repository status to $output_file"
    dialog --msgbox "Repository status saved to $output_file" $(calculate_dialog_size)
}

# Function to load and apply repository status
load_and_apply_repo_status() {
    local default_file=$(ls -t repo_status_*.csv 2>/dev/null | head -n1)
    local input_file=$(dialog --title "Load Repository Status" --inputbox "Enter filename to load status (default: $default_file):" 10 60 "$default_file" 2>&1 >/dev/tty)
    
    if [ $? -ne 0 ] || [ -z "$input_file" ]; then
        log "Operation cancelled or empty filename provided for loading repository status"
        dialog --msgbox "Operation cancelled or empty filename provided." $(calculate_dialog_size)
        return
    fi

    if [ ! -f "$input_file" ]; then
        log "File not found: $input_file"
        dialog --msgbox "File not found: $input_file" $(calculate_dialog_size)
        return
    fi

    # Check if the file is readable
    if [ ! -r "$input_file" ]; then
        log "Cannot read file: $input_file. Please check permissions."
        dialog --msgbox "Cannot read file: $input_file. Please check permissions." $(calculate_dialog_size)
        return
    fi

    # Validate file content
    if ! grep -qE '^[^,]+,(public|private),(true|false)$' "$input_file"; then
        log "Invalid file format in $input_file"
        dialog --msgbox "Invalid file format. Each line should be 'repo,visibility,isArchived'." $(calculate_dialog_size)
        return
    fi

    log "Starting to apply repository status from $input_file"
    while IFS=',' read -r repo visibility is_archived; do
        if ! validate_repo_name "$repo"; then
            log "Invalid repository name: $repo. Skipping."
            dialog --msgbox "Invalid repository name: $repo. Skipping." $(calculate_dialog_size)
            continue
        fi
        dialog --yesno "Change $repo to $visibility and archive status to $is_archived?" $(calculate_dialog_size)
        if [ $? -eq 0 ]; then
            log "Attempting to change $repo to $visibility and archive status to $is_archived"
            if toggle_repo_visibility "$repo"; then
                if [ "$is_archived" = "true" ]; then
                    if gh repo edit "$repo" --archived; then
                        log "Successfully changed $repo to $visibility and archived"
                        dialog --msgbox "Successfully changed $repo to $visibility and archived" $(calculate_dialog_size)
                    else
                        log "Changed $repo to $visibility but failed to archive"
                        dialog --msgbox "Changed $repo to $visibility but failed to archive" $(calculate_dialog_size)
                    fi
                else
                    if gh repo edit "$repo" --unarchived; then
                        log "Successfully changed $repo to $visibility and unarchived"
                        dialog --msgbox "Successfully changed $repo to $visibility and unarchived" $(calculate_dialog_size)
                    else
                        log "Changed $repo to $visibility but failed to unarchive"
                        dialog --msgbox "Changed $repo to $visibility but failed to unarchive" $(calculate_dialog_size)
                    fi
                fi
            else
                log "Failed to change $repo to $visibility"
                dialog --msgbox "Failed to change $repo to $visibility" $(calculate_dialog_size)
            fi
        else
            log "User skipped changing $repo"
        fi
    done < "$input_file"

    log "Finished applying repository status from $input_file"
    dialog --msgbox "Finished applying repository status from $input_file" $(calculate_dialog_size)
}

# Function to change repository visibility
change_repo_visibility() {
    local repo="$1"
    local new_visibility="$2"
    local current_visibility

    # Get current visibility
    current_visibility=$(gh repo view "$repo" --json isPrivate --jq 'if .isPrivate then "private" else "public" end')

    if [ "$current_visibility" = "$new_visibility" ]; then
        log "Repository $repo is already $new_visibility"
        return 0
    fi

    # Change visibility
    if gh repo edit "$repo" --visibility "$new_visibility"; then
        log "Successfully changed $repo to $new_visibility"
        return 0
    else
        log "Failed to change $repo to $new_visibility"
        return 1
    fi
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
        dialog --msgbox "No repositories found matching the keyword: $keyword" $(calculate_dialog_size)
        return
    fi

    show_repo_selection_menu "$repos"
}

# Function to calculate dialog size
calculate_dialog_size() {
    local min_height=${1:-8}
    local min_width=${2:-40}
    local term_lines=$(tput lines)
    local term_cols=$(tput cols)
    
    local dialog_height=$((term_lines * 80 / 100))
    local dialog_width=$((term_cols * 80 / 100))
    
    dialog_height=$((dialog_height < min_height ? min_height : dialog_height))
    dialog_width=$((dialog_width < min_width ? min_width : dialog_width))
    
    echo "$dialog_height $dialog_width"
}

# Function to display detailed repository information
show_repo_details() {
    local repo="$1"
    local repo_info
    local error_message
    local commit_info

    log "Fetching repository information for $repo"
    if ! repo_info=$(gh repo view "$repo" --json name,description,url,homepageUrl,defaultBranchRef,isPrivate,isArchived,createdAt,updatedAt,pushedAt,diskUsage,languages,licenseInfo,stargazerCount,forkCount,issues,pullRequests 2>&1); then
        error_message="Failed to fetch repository information for $repo. Error: $repo_info"
        log "$error_message"
        dialog --title "Error" $(calculate_dialog_size) --msgbox "$error_message"
        return
    fi

    if [ -z "$repo_info" ]; then
        error_message="No information retrieved for repository $repo"
        log "$error_message"
        dialog --title "Error" $(calculate_dialog_size) --msgbox "$error_message"
        return
    fi

    log "Successfully fetched repository information for $repo"
    log "Raw repository info: $repo_info"

    # Use a single jq command to extract all information
    local repo_details=$(echo "$repo_info" | jq -r '
        "Name: \(.name // "N/A")
        Description: \(.description // "N/A")
        URL: \(.url // "N/A")
        Homepage: \(.homepageUrl // "N/A")
        Default Branch: \(.defaultBranchRef.name // "N/A")
        Visibility: \(if .isPrivate then "Private" else "Public" end)
        Archived: \(if .isArchived then "Yes" else "No" end)
        Created: \(.createdAt[0:10] // "N/A")
        Last Updated: \(.updatedAt[0:10] // "N/A")
        Last Pushed: \(.pushedAt[0:10] // "N/A")
        Disk Usage: \(.diskUsage // "N/A") KB
        Primary Language: \((.languages | keys)[0] // "N/A")
        License: \(.licenseInfo.name // "N/A")
        Stars: \(.stargazerCount // "N/A")
        Forks: \(.forkCount // "N/A")
        Open Issues: \(.issues.totalCount // "N/A")
        Open Pull Requests: \(.pullRequests.totalCount // "N/A")"
    ')

    # Fetch commit count
    local commit_count=$(gh api "repos/$repo/commits?per_page=1" --jq 'total_count' 2>/dev/null || echo "N/A")
    
    # Fetch committer count
    local committer_count=$(gh api "repos/$repo/contributors?per_page=100" --jq 'length' 2>/dev/null || echo "N/A")
    
    log "Fetched commit count: $commit_count, committer count: $committer_count"

    local details="${repo_details}
Commit Count: $commit_count
Committer Count: $committer_count"

    log "Formatted repository details for $repo: $details"
    
    dialog --title "Repository Details: $repo" --msgbox "$details" $(calculate_dialog_size)
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
            if ! all_repos=$(get_all_repositories); then
                continue
            fi
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
            dialog --msgbox "Invalid option. Please try again." $(calculate_dialog_size)
            ;;
    esac
done
