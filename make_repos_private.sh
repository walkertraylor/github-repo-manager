#!/bin/bash

 # Function to change repo visibility
 change_repo_visibility() {
     local repo="$1"
     if gh repo edit "$repo" --visibility private; then
         echo "✅ Changed $repo to private"
     else
         echo "❌ Failed to change $repo to private"
     fi
 }

 # Main script
 echo "Changing all public repositories to private..."
 echo "This may take a while depending on the number of repositories."

 # Get list of public repositories
 public_repos=$(gh repo list --json nameWithOwner,visibility --jq '.[] | select(.visibility == "public") |
 .nameWithOwner')

 # Check if there are any public repos
 if [ -z "$public_repos" ]; then
     echo "No public repositories found."
     exit 0
 fi

 # Count of repositories
 total_repos=$(echo "$public_repos" | wc -l)
 current=0

 # Loop through repositories and change visibility
 echo "$public_repos" | while read -r repo; do
     ((current++))
     echo "[$current/$total_repos] Processing $repo"
     change_repo_visibility "$repo"
 done

 echo "Finished processing all repositories."
