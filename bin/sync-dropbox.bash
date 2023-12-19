# set ft=bash
# Template:
#
# Merge changes in $org_repo from Dropbox into repo, and then upload repo
# contents back to Dropbox for use by Orgzly.
#
# Meant to be sourced by a Bash script. Before sourcing, set the following
# variables: org_repo, dropbox_local_root, dropbox_org
#
# Options:
#   -l: Use rsync and a local directory instead of dbxcli
#
#

set -eu
set -o pipefail

: ${org_repo?:"Set org_repo to location of org repo on this machine"}
: ${dropbox_local_root?:"Set dropbox_local_root to location of Dropbox directory on this machine"}
: ${dropbox_org?:"Set dropbox_org to location of org repo directory relative to Dropbox root"}

cd "$org_repo"

( getopt --version | grep -e 'getopt (enhanced)' -e 'util-linux' ) &>/dev/null || {
  echo "GNU getopt not on path" 1>&2
  exit 1
}
options=$(getopt -o lpn -- "$@")
eval set -- "$options"
local_mode=0
push_mode=0
no_prompt=0
while true; do
    case "$1" in
    -l)
        local_mode=1
        ;;
    -p)
        push_mode=1
        ;;
    -n)
        no_prompt=1
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

if [ "$no_prompt" -ne 1 ]; then
    echo
    echo '========================================'
    echo '       Sync Orgzly on device now        '
    echo '========================================'
    echo
    read -rsp $'Press any key to continue...\n' -n1 _key
fi

# Refresh Dropbox token if necessary
"$(dirname ${BASH_SOURCE[0]})/dbxcli-refresh"

dbxcli_list_revs_files () {
    base_dir="$1"
    dbxcli ls -l "$1" | awk '
        NR==1 { fname_pos = match($0, /Path/); next; }
        NR > 1 {
            # Skip if not a file
            rev = $1;
            if (rev == "-" ) { next; }
            fname = substr($0, fname_pos, length($0));
            sub(/ *$/, "", fname);
            print rev "\t" fname;
        }
    ' | sort
}

current_branch=$(git symbolic-ref --short HEAD)
dropbox_git_base=.HEAD
dropbox_list=.dropbox-list
tmp_branch=dropbox-merge-$RANDOM
git_base_commit=$(
    if [ "$local_mode" -eq 1 ]; then
        cat "$dropbox_local_root$dropbox_org/$dropbox_git_base"
    elif ! dbxcli ls -l "$dropbox_org/$dropbox_git_base" &>/dev/null; then
        git rev-parse HEAD
    else
        dbxcli get "$dropbox_org/$dropbox_git_base" \
            "$dropbox_git_base"
        cat "$dropbox_git_base"
    fi
)

get_and_merge () {
    git checkout -b "$tmp_branch" "$git_base_commit"

    if [ "$local_mode" -eq 1 ]; then
        rsync -r --progress --exclude=.HEAD --exclude='*.org_archive' \
            "$dropbox_local_root$dropbox_org/" .
    else
        [ -e "$dropbox_list" ] || touch "$dropbox_list"
        dbxcli_list_revs_files "$dropbox_org" | \
            $( : "Get list of files changed or added remotely" ) \
            comm -3 "$dropbox_list" - | awk '/^\t/ { print; }' | \
            cut -d $'\t' -f3- | \
            $( : "Remove several files we don't care about" ) \
            awk '
                /^$/ { next; }
                {
                    if ( $0 == "'"$dropbox_org/$dropbox_git_base"'" ||
                         $0 == "'"$dropbox_org/$dropbox_list"'") {
                        next;
                    }
                    print;
            }' | tr '\n' '\0' | xargs -t -0 -n1 bash -c '
                [ -z "$1" ] && exit 0
                dbxcli get "$1" "$(echo "$1" | sed "s!^${0}!.!")"
            ' "$dropbox_org"
    fi

    # Strip trailing blank lines from Org-mode files - Orgzly has a habit of
    # introducing them.
    while IFS= read -r -d '' file; do
        local iargs
        # Non-GNU sed (detected by lack of `--version` flag) requires empty
        # arg after `-i` flag, which GNU sed doesn't accept.
        if ! sed --version &>/dev/null; then
            iargs=( "-i" "" )
        else
            iargs=( "-i" )
        fi
        sed "${iargs[@]}" -e :a -e '/^\n*$/{$d;N;};/\n$/ba' "$file"
    done < <(git ls-files -z | perl -n0e 'print if /.*\.(org|org_archive)\0/')

    # Only commit if working directory dirty - see
    # https://unix.stackexchange.com/a/394674/21394
    if [ -n "$(git status --untracked-files=no --porcelain)" ]; then
        git commit -a -m "Dropbox merge $(date)"
    fi
    git checkout "$current_branch"
    git merge -m "Merge branch '$tmp_branch'" "$tmp_branch"
    git branch -d "$tmp_branch"
}

if [ "$push_mode" -ne 1 ]; then
    get_and_merge
fi

# Upload files to Dropbox
# TODO: delete files in Dropbox not in Git repo in dbxcli mode
git diff -z --name-only "$git_base_commit" | { \
    # Exclude files that shouldn't be uploaded to Dropbox.
    # Use Perl because MacOS grep doesn't support ASCII NUL-separated input.
    # `\0` needed in regex because lines end with that, not `\n`, so `/$/`
    # doesn't work.
    perl -0 -ne 'print unless /gcal.*\.org/ || /\.org_archive\0/'
  } | {
    if [ "$local_mode" -eq 1 ]; then
        rsync --progress --delete -0 --files-from=/dev/stdin \
            . "$dropbox_local_root$dropbox_org/"
        git rev-parse HEAD > \
            "$dropbox_local_root$dropbox_org/$dropbox_git_base"
    else
        xargs -t -0 -n1 bash -c '
            [ -z "$1" ] && exit 0
            if [ -e "$1" ]; then
                dbxcli put "$1" "$0/$1"
            else
                # Ignore failure to remove files, which can happen if remote
                # file no longer exists.
                dbxcli rm -f "$0/$1" || true
            fi
        ' "$dropbox_org"
        dbxcli put <(git rev-parse HEAD) "$dropbox_org/$dropbox_git_base"
        dbxcli_list_revs_files "$dropbox_org" > "$dropbox_list"
    fi
}

if [ "$no_prompt" -ne 1 ]; then
    echo
    echo '========================================'
    echo '       Sync Orgzly on device now        '
    echo '========================================'
    echo
    read -rsp $'Press any key to continue...\n' -n1 _key
fi
