# set ft=bash
set -eu -o pipefail

# Meant to be sourced by a script that sets these header variables.
: "${source_home?}"
: "${backup_home?}"
: "${source_promnesia_dir?}"
: "${backup_promnesia_dir?}"
: "${source_db?}"
: "${backup_db?}"
: "${source_config?}"
: "${backup_config?}"
: "${backup_host_tailscale?}"
: "${backup_host_lan?}"

backup_host=${backup_host_tailscale}
if timeout 3 ssh "$backup_host_lan" 'true' &>/dev/null; then
    backup_host=${backup_host_lan}
fi

cd "$source_promnesia_dir"
sqlite3 "$source_db" ".backup ${backup_db}"
sqlite3 "$backup_db" <<EOF
-- Need to set this PRAGMA because we're updating fields from the command line
-- that have triggers set on the virtual table for full-text search.
-- See https://stackoverflow.com/a/76344213/207384.
-- If not set, the following message is displayed:
-- unsafe use of virtual table "visits_fts"
PRAGMA trusted_schema=1;
UPDATE
    visits
SET
    locator_href = REPLACE(locator_href, '${source_home}', '${backup_home}')
WHERE
    src in ('home-org', 'tiktok-org', 'exobrain');
UPDATE
    visits
SET
    locator_title = REPLACE(locator_title, '${source_promnesia_dir}', '${backup_promnesia_dir}'),
    locator_href = REPLACE(locator_href, '${source_promnesia_dir}', '${backup_promnesia_dir}')
WHERE
    src in ('chrome-history-personal', 'chrome-history-corp');
EOF
cp "$source_config" "$backup_config"
sed -i '' -e "s|${source_promnesia_dir}|${backup_promnesia_dir}|g" \
    -e "s|${source_home}|${backup_home}|g" "$backup_config"
ssh "${backup_host}" "mkdir -p \"${backup_promnesia_dir}\""
rsync -a "$backup_db" "${backup_host}":"${backup_promnesia_dir}/${source_db}" &
rsync -a "$backup_config" "${backup_host}":"${backup_promnesia_dir}/${source_config}" &
rsync -a chrome-history-export-personal chrome-history-export-corp \
    "${backup_host}":"${backup_promnesia_dir}" &
wait
