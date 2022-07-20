#!/bin/bash

# MIT License
#
# Copyright (c) 2022 Tom SIMONART
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -e

SDFM_DIR=$HOME/.sdfm
STORAGE=$SDFM_DIR/storage
TRACK_FILE=$SDFM_DIR/track_file
COLOR=true

C_R=31
C_G=32
C_Y=33
C_B=34

function info {
    color $C_B false "I "
    color 0 true "$@"
}

function ok {
    color 0 false "$@"
    color $C_G true " OK"
}

function nok {
    color 0 false "$@"
    color $C_R true " NOT OK"
}

function success {
    color $C_G false "S "
    color 0 true "$@"
}

function warning {
    color $C_Y false "W "
    color 0 true "$@"
}

function error {
    color $C_R false "E "
    color 0 true "$@"
}

function error_exit {
    error "$@"
    exit 1
}

function color {
    local args
    local color=$1; shift
    local newline=$1; shift
    ! $newline && args+=" -n"
    local msg="$@"
    if $COLOR; then
        args+=" -e"
        echo $args "\x1b[1;${color}m${msg}\x1b[0m" >&2
    else
        echo $args "$msg" >&2
    fi
}

function cleanup {
    # Delete empty directories
    find "$STORAGE" -empty -delete
}

function get_path {
    # Get the absolute path of a file
    echo $(realpath -s "$1")
}

function get_storage_path {
    # Get the absolute path to the storage
    echo "${STORAGE}${1}"
}

function cmd_exists {
    if which "$1" &> /dev/null; then
        return 0
    fi
    return 1
}

function list {
    info "Listing tracked files"
    while read -r path; do
        color $C_G false "-> "
        echo "'$path'"
    done <<< $(sort "$TRACK_FILE");
}

function create_link_to_storage {
    # Create a symlink to the storage for a given path, create a backup if overwrited
    local path=$(get_path "$1")
    local storage_path=$(get_storage_path "$path")
    if [[ -f "$path" ]]; then
        warning "File found here: '$path' a backup (with suffix '~') has been created."
    fi
    ln --backup=simple --no-target-directory --symbolic "$storage_path" "$path"
}

function confirm {
    local msg="$@"
    local confirm
    read -p "$msg ? [Yes/No] " confirm
    if [[ "$confirm" = "Yes" ]]; then
        return 0
    fi
    return 1
}

function check_file_in_directory {
    local path="$1"
    local directory="$2"
    local relative_to_path=$(realpath -s "$path" --relative-to "$directory")
    if [[ $(echo "$relative_to_path" | head -c 3) = "../" ]]; then
        return 1
    fi
    return 0
}

function track {
    local path=$(get_path "$1")
    local storage_path=$(get_storage_path "$path")

    # Checks and warnings
    if [[ -z "$path" ]]; then
        error_exit "Please provide a file to track"
    elif [[ "$path" = "$HOME" ]] || [[ "$path" = "/home" ]]; then
        error_exit "It would not be wise to track the entire home directory"
    elif [[ "$path" = "/" ]]; then
        error_exit "It would not be wise to track the root directory"
    elif check_file_in_directory "$path" "$SDFM_DIR"; then
        error_exit "You should not track sdfm's own runtime files"
    elif ! check_file_in_directory "$path" "$HOME"; then
        warning "Path outside of home directory, this is not recommended"
        confirm "Continue anyways" || (success "You made the right choice" ; exit 1)
    fi

    # Do not track if it's a symbolic link or if path exists in the storage
    if ! ([[ -d "$storage_path" ]] || [[ -f "$storage_path" ]]); then
        if [[ ! -L "$path" ]]; then
            confirm "Copy '$path' to '$storage_path'" && cp --parents --no-clobber --recursive "$path" "$STORAGE"
            confirm "Delete '$path'" && rm -rf "$path"
            create_link_to_storage "$path"
            # Add path to track file
            echo "$path" >> "$TRACK_FILE"
        else
            error_exit "Path is a symbolic link"
        fi
    else
        error_exit "Path is already tracked"
    fi
    success "File tracked"
}

function untrack {
    # Move files back to their initial location
    local path=$(get_path "$1")
    local storage_path=$(get_storage_path "$path")
    # Only untrack if it's a symlink to a file/dir present in the storage
    if [[ -d "$storage_path" ]] || [[ -f "$storage_path" ]]; then
        if [[ -L "$path" ]]; then
            confirm "Delete '$path'" && rm -rf "$path"
            confirm "Move '$storage_path' to '$path'" && mv --no-clobber --no-target-directory "$storage_path" "$path"
            sed -i '\|^'"$path"'$|d' $TRACK_FILE  # Remove path from track file
        else
            error_exit "Path is parent or child of a tracked directory"
        fi
    else
        error_exit "Path is not tracked"
    fi
    cleanup
    success "File untracked"
}

function install {
    # Make symbolic links to storage files when they don't exist
    while read -r path; do
        storage_path=$(get_storage_path "$path")
        if [[ ! -L "$path" ]] || [[ ! $(readlink "$path") = "$storage_path" ]]; then
            info "Installing '$storage_path'"
            create_link_to_storage "$path"
            ok "'$path'"
        else
            info "Skipping '$storage_path'"
        fi
    done <<< $(sort "$TRACK_FILE")
    success "Installation done"
}

function check {
    info "Checking dotfiles"
    while read -r path; do
        storage_path=$(get_storage_path "$path")
        if ([[ -f "$storage_path" ]] || [[ -d "$storage_path" ]]); then
            if [[ -L "$path" ]]; then
                if [[ $(readlink "$path") = "$storage_path" ]]; then
                    ok "'$path'"
                else
                    nok "'$path'"
                    error "Symbolic link does not link to storage path"
                fi
            else
                nok "'$path'"
                error "File is tracked, but not installed"
            fi
        else
            nok "'$path'"
            error "File not in storage"
        fi
    done <<< $(sort "$TRACK_FILE")
}

function usage {
    echo "$0 [track|untrack PATH] | [install|list|check|license] | [git|cmd CMD]"
}

# Always create storage directory and track file
mkdir -p "$STORAGE"
touch "$TRACK_FILE"

# Parse arguments
case "$1" in
    list|l)
        list
        ;;
    check|C|status|s|st)
        check
        ;;
    cmd|c)
        shift
        pushd "$STORAGE" >/dev/null
        $@
        popd >/dev/null
        ;;
    git|g)
        shift
        pushd "$SDFM_DIR" >/dev/null
        git $@
        popd >/dev/null
        ;;
    track|t)
        track "$2"
        ;;
    untrack|u)
        untrack "$2"
        ;;
    install|i)
        install
        ;;
    license)
        head -n 23 $0 | tail -n 21
        ;;
    help)
        usage
        ;;
    *)
        error "Unknown command"
        usage
        exit 1
        ;;
esac
