#!/bin/bash

# Script to find branches with multiple merge bases against default branch
# Usage: ./find_multiple_merge_bases.sh [REPOSITORY_PATH]
#
# Arguments:
#   REPOSITORY_PATH  Path to the git repository (default: current directory)

# Get repository path from argument or use current directory
REPO_PATH="${1:-.}"

# Change to the repository directory
if ! cd "$REPO_PATH" 2>/dev/null; then
    echo "Error: Cannot access repository path: $REPO_PATH" >&2
    exit 1
fi

# Verify it's a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: $REPO_PATH is not a git repository" >&2
    exit 1
fi

echo "Repository: $(pwd)"

# Auto-detect the default branch
default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
if [ -z "$default_branch" ]; then
    # Fallback: try to detect from remote
    default_branch=$(git remote show origin 2>/dev/null | grep 'HEAD branch:' | cut -d' ' -f5)
fi
if [ -z "$default_branch" ]; then
    # Final fallback: assume master
    default_branch="master"
fi

echo "Auto-detected default branch: $default_branch"
echo "Searching for branches with multiple merge bases against $default_branch..."
echo "=================================================="

# Get all branches, filtering out default branch and HEAD references
branches=$(git branch -a | grep -v '^\*' | sed 's/^[ ]*//; s/^remotes\///' | grep -v '^origin/HEAD' | grep -v "^${default_branch}$" | grep -v "^origin/${default_branch}$" | sort -u)

count=0
total=$(echo "$branches" | wc -l)

for branch in $branches; do
    count=$((count + 1))
    echo -n "[$count/$total] Testing $branch... "
    
    # Run git merge-base --all and count the results
    merge_bases=$(git merge-base --all "$branch" "$default_branch" 2>/dev/null)
    exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo "ERROR (cannot find merge base)"
        continue
    fi
    
    num_bases=$(echo "$merge_bases" | wc -l)
    
    if [ "$num_bases" -gt 1 ]; then
        echo "FOUND MULTIPLE MERGE BASES!"
        echo "Branch: $branch"
        echo "Number of merge bases: $num_bases"
        echo "Merge bases:"
        echo "$merge_bases"
        echo "=================================================="
        echo "STOPPING - Found branch with multiple merge bases against $default_branch: $branch"
        exit 0
    else
        echo "OK (1 merge base)"
    fi
    
    # Show progress every 50 branches
    if [ $((count % 50)) -eq 0 ]; then
        echo "Progress: $count/$total branches checked"
    fi
done

echo "=================================================="
echo "Completed checking all $total branches. No branches with multiple merge bases found."
