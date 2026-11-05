#!/usr/bin/env bash
# Keeps ETEA up to date from the git clone it runs from.
#   update.sh info    "commit|date|branch" of what's running
#   update.sh check   how many new commits there are, then their titles
#   update.sh apply   moves to the latest version; the Updater service then reloads the shell
# Exits 2 when the server can't be reached, 3 when this isn't a clone that follows one,
# 4 when files were changed here by hand, 5 when the history went elsewhere.
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 3

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 3
# ETEA's own clone, not some bigger repository it happens to sit in, like a dotfiles one
[[ "$(git rev-parse --show-toplevel)" == "$(pwd -P)" ]] || exit 3

case "${1:-}" in
    info)
        printf '%s|%s|%s\n' "$(git rev-parse --short HEAD)" "$(git log -1 --format=%cs)" "$(git branch --show-current)"
        ;;
    check)
        upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" || exit 3
        timeout 30 git fetch --quiet "${upstream%%/*}" 2>/dev/null || exit 2
        git rev-list --count 'HEAD..@{u}'
        git log --format=%s 'HEAD..@{u}' | head -8
        ;;
    apply)
        git rev-parse '@{u}' >/dev/null 2>&1 || exit 3
        # Never over someone's own changes
        [[ -z "$(git status --porcelain --untracked-files=no)" ]] || exit 4
        git merge --ff-only --quiet '@{u}' 2>/dev/null || exit 5
        ;;
    *)
        sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
        exit 1
        ;;
esac
