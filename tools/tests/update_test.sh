#!/usr/bin/env bash
# All operations are confined to fake installations below the repository's tmp/.
# No real downloads, system services, /etc files or installed panels are changed.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
mkdir -p "$repo/tmp"
suite=$(mktemp -d "$repo/tmp/sg-update-tests.XXXXXX")
trap 'rm -rf -- "$suite"' EXIT
export UPDATER="$repo/update.sh" FIXTURE_ROOT="$suite/fixtures"
mkdir -p "$FIXTURE_ROOT/x-ui"
cat > "$FIXTURE_ROOT/x-ui/x-ui" <<'BIN'
#!/bin/sh
printf '3.1.0-sg3\n'
BIN
cat > "$FIXTURE_ROOT/menu.sh" <<'MENU'
#!/bin/sh
# SG management menu fixture
printf 'new-sg-menu\n'
MENU
chmod +x "$FIXTURE_ROOT/x-ui/x-ui"
(cd "$FIXTURE_ROOT" && tar -czf x-ui-linux-amd64.tar.gz x-ui && sha256sum x-ui-linux-amd64.tar.gz > SHA256SUMS)
cat > "$suite/worker.sh" <<'WORKER'
set -euo pipefail
source "$UPDATER"
sg_arch() { echo amd64; }
sg_service_setup() { sg_manager=mock; }
sg_database_setup() {
    sg_db_type=${TEST_DB_TYPE:-sqlite}
    sg_db_folder=$XUI_DB_FOLDER
    sg_db_file=$XUI_DB_FOLDER/x-ui.db
    sg_db_dsn='postgres://mock-database'
    [[ -f "$sg_db_file" ]]
}
sg_fetch() {
    [[ ${FAIL_DOWNLOAD:-0} == 0 ]] || return 1
    local out='' url=''
    while [[ $# -gt 0 ]]; do
        case "$1" in --output) out=$2; shift 2 ;; *) url=$1; shift ;; esac
    done
    case "$url" in
        */releases/latest) printf 'https://github.com/ShiGuangDe/3x-ui-sg/releases/tag/%s' "${LATEST_TAG:-v3.1.0-sg3}" ;;
        */x-ui-linux-amd64.tar.gz) cp "$FIXTURE_ROOT/${ASSET_FILE:-x-ui-linux-amd64.tar.gz}" "$out" ;;
        */SHA256SUMS)
            if [[ ${BAD_HASH:-0} == 1 ]]; then printf '%064d  x-ui-linux-amd64.tar.gz\n' 0 > "$out"
            else cp "$FIXTURE_ROOT/${HASH_FILE:-SHA256SUMS}" "$out"; fi ;;
        https://raw.githubusercontent.com/ShiGuangDe/3x-ui-sg/main/x-ui.sh)
            if [[ ${BAD_MENU:-0} == 1 ]]; then echo 'if broken' > "$out"; else cp "$FIXTURE_ROOT/menu.sh" "$out"; fi ;;
        https://raw.githubusercontent.com/MHSanaei/3x-ui/main/update.sh)
            printf '#!/bin/sh\nprintf official > "%s/official-called"\n' "$XUI_UPDATE_STATE_DIR" > "$out" ;;
        *) printf 'Unexpected network request: %s\n' "$url" >&2; return 1 ;;
    esac
}
sg_service() {
    printf '%s\n' "$1" >> "$XUI_UPDATE_STATE_DIR/service-calls"
    case "$1" in
        active) [[ $(cat "$XUI_UPDATE_STATE_DIR/service-state") == running ]] ;;
        stop)
            [[ ${FAIL_STOP:-0} == 0 ]] || return 1
            echo stopped > "$XUI_UPDATE_STATE_DIR/service-state" ;;
        start)
            if [[ $("$XUI_MAIN_FOLDER/x-ui" -v) == 3.1.0-sg3 && ${FAIL_START:-0} == 1 ]]; then
                echo migrated > "$XUI_DB_FOLDER/x-ui.db"
                echo stale-wal > "$XUI_DB_FOLDER/x-ui.db-wal"
                return 1
            fi
            echo running > "$XUI_UPDATE_STATE_DIR/service-state" ;;
    esac
}
# Keep the real health loop, but avoid waiting during mocked process checks.
sleep() { :; }
cp() {
    if [[ ${FAIL_BACKUP:-0} == 1 && "${!#}" == "$XUI_BACKUP_DIR"/*/x-ui.db ]]; then return 1; fi
    command cp "$@"
}
eval "$(declare -f sg_atomic_install | sed '1s/sg_atomic_install/real_sg_atomic_install/')"
sg_atomic_install() {
    if [[ ${FAIL_REPLACE:-0} == 1 && "$2" == "$XUI_CLI_PATH" ]]; then return 1; fi
    real_sg_atomic_install "$@"
    if [[ ${SIGNAL_UPDATE:-0} == 1 && "$2" == "$XUI_MAIN_FOLDER/x-ui" ]]; then kill -TERM "$BASHPID"; fi
}
pg_dump() {
    [[ ${FAIL_PG_DUMP:-0} == 0 ]] || return 1
    [[ $PGDATABASE == postgres://mock-database ]]
    local arg
    for arg in "$@"; do if [[ $arg == --file=* ]]; then command cp "$XUI_DB_FOLDER/x-ui.db" "${arg#--file=}"; fi; done
}
pg_restore() {
    command cp "${!#}" "$XUI_DB_FOLDER/x-ui.db"
    echo restored > "$XUI_UPDATE_STATE_DIR/postgres-restored"
}
if [[ ${WRAPPER_TEST:-0} != 0 ]]; then
    source <(sed -n '/^update() {/,/^legacy_version() {/p' "${UPDATER%/*}/x-ui.sh" | sed '$d')
    xui_folder=$XUI_MAIN_FOLDER
    LOGI() { echo "$*"; }; LOGE() { echo "$*" >&2; }
    before_show_menu() { echo unexpected-interactive-return >&2; return 1; }
    curl() {
        local out='' url=''
        while [[ $# -gt 0 ]]; do
            case "$1" in --output) out=$2; shift 2 ;; *) url=$1; shift ;; esac
        done
        case "$url" in
            https://raw.githubusercontent.com/ShiGuangDe/3x-ui-sg/main/update.sh)
                printf '#!/bin/sh\nprintf "%%s\\n" "$@" > "%s/arguments"\n' "$XUI_UPDATE_STATE_DIR" > "$out" ;;
            https://raw.githubusercontent.com/ShiGuangDe/3x-ui-sg/main/x-ui.sh) cp "$FIXTURE_ROOT/menu.sh" "$out" ;;
            *) return 1 ;;
        esac
    }
    case "$WRAPPER_TEST" in
        menu) update_menu ;;
        install | install-default)
            source <(sed -n '/^normalize_install_version() {/,/^select_install_version() {/p' "${UPDATER%/*}/install.sh" | sed '$d')
            [[ $(normalize_install_version sg1) == v3.1.0-sg1 ]]
            [[ $(normalize_install_version sg2) == v3.1.0-sg2 ]]
            [[ $(normalize_install_version 3) == v3.1.0-sg3 ]]
            if [[ "$WRAPPER_TEST" == install ]]; then update_existing_installation sg3; else update_existing_installation; fi
            ;;
        *) update 0 sg v3.1.0-sg3 ;;
    esac
elif [[ ${OFFICIAL_TEST:-0} == 1 ]]; then sg_official; else sg_update "${TARGET_TAG:-}"; fi
WORKER

# Bash may be installed as sh.exe in portable Windows Git runtimes.
shell=${BASH:-bash}
case_count=0
new_case() {
    case_count=$((case_count + 1))
    local base="$suite/case-$case_count"
    export XUI_MAIN_FOLDER="$base/panel" XUI_CLI_PATH="$base/cli/x-ui"
    export XUI_DB_FOLDER="$base/db" XUI_UPDATE_STATE_DIR="$base/state" XUI_BACKUP_DIR="$base/backups"
    mkdir -p "$XUI_MAIN_FOLDER/bin" "$base/cli" "$XUI_DB_FOLDER" "$XUI_UPDATE_STATE_DIR"
    printf '#!/bin/sh\nprintf "%s\\n"\n' "${1:-3.1.0-sg2}" > "$XUI_MAIN_FOLDER/x-ui"
    chmod +x "$XUI_MAIN_FOLDER/x-ui"
    echo old-menu > "$XUI_MAIN_FOLDER/x-ui.sh"
    echo old-cli > "$XUI_CLI_PATH"
    echo original-db > "$XUI_DB_FOLDER/x-ui.db"
    echo certificate > "$XUI_MAIN_FOLDER/cert.pem"
    echo core > "$XUI_MAIN_FOLDER/bin/xray-linux-amd64"
    echo running > "$XUI_UPDATE_STATE_DIR/service-state"
    unset FAIL_START FAIL_REPLACE FAIL_BACKUP FAIL_DOWNLOAD FAIL_STOP BAD_HASH LATEST_TAG TARGET_TAG TEST_DB_TYPE OFFICIAL_TEST ASSET_FILE HASH_FILE BAD_MENU FAIL_PG_DUMP SIGNAL_UPDATE WRAPPER_TEST EXPECT_EXISTING_LOCK
}
run_case() {
    local expected=$1 status=0
    shift
    "$shell" "$suite/worker.sh" > "$XUI_UPDATE_STATE_DIR/result.log" 2>&1 || status=$?
    if [[ $expected == success && $status != 0 || $expected == failure && $status == 0 ]]; then
        cat "$XUI_UPDATE_STATE_DIR/result.log"; echo "FAIL: $* (exit $status)" >&2; exit 1
    fi
    if [[ ${EXPECT_EXISTING_LOCK:-0} == 0 && -d "$XUI_UPDATE_STATE_DIR/lock" ]]; then
        cat "$XUI_UPDATE_STATE_DIR/result.log"; echo "FAIL: updater left its own lock behind: $*" >&2; exit 1
    fi
    echo "PASS: $*"
}
old_intact() {
    [[ $("$XUI_MAIN_FOLDER/x-ui" -v) == 3.1.0-sg2 ]]
    [[ $(cat "$XUI_CLI_PATH") == old-cli && $(cat "$XUI_MAIN_FOLDER/x-ui.sh") == old-menu ]]
    [[ $(cat "$XUI_DB_FOLDER/x-ui.db") == original-db ]]
    [[ $(cat "$XUI_UPDATE_STATE_DIR/service-state") == running ]]
}
no_stop() { [[ ! -f "$XUI_UPDATE_STATE_DIR/service-calls" ]] || ! grep -qx stop "$XUI_UPDATE_STATE_DIR/service-calls"; }

# Ensure bash -n in the updater can run on both Linux and portable Git for Windows.
mkdir "$suite/commands"
ln -s "$shell" "$suite/commands/bash" 2>/dev/null || cp "$shell" "$suite/commands/bash.exe"
export PATH="$suite/commands:$PATH"
new_case; run_case success 'SG update preserves data, certificates and Xray'
[[ $("$XUI_MAIN_FOLDER/x-ui" -v) == 3.1.0-sg3 ]]
grep -q new-sg-menu "$XUI_CLI_PATH"
[[ $(cat "$XUI_DB_FOLDER/x-ui.db") == original-db && $(cat "$XUI_MAIN_FOLDER/cert.pem") == certificate ]]
[[ $(cat "$XUI_MAIN_FOLDER/bin/xray-linux-amd64") == core ]]
[[ ! -d "$XUI_UPDATE_STATE_DIR/lock" ]]
[[ $(find "$XUI_BACKUP_DIR" -name x-ui.db | wc -l) == 1 ]]
new_case; export FAIL_START=1; run_case failure 'failed startup restores binary, menus and database'; old_intact
[[ ! -e "$XUI_DB_FOLDER/x-ui.db-wal" && ! -d "$XUI_UPDATE_STATE_DIR/lock" ]]
new_case; export FAIL_REPLACE=1; run_case failure 'partial replacement is rolled back'; old_intact
new_case; export FAIL_BACKUP=1; run_case failure 'failed backup restarts original service without replacement'; old_intact
new_case; export FAIL_STOP=1; run_case failure 'failed stop leaves original installation intact'; old_intact
new_case; export BAD_HASH=1; run_case failure 'checksum mismatch never stops service'; old_intact; no_stop
new_case; export BAD_MENU=1; run_case failure 'invalid downloaded menu never stops service'; old_intact; no_stop
new_case; export FAIL_DOWNLOAD=1; run_case failure 'download failure leaves installation intact'; old_intact; no_stop
new_case; export LATEST_TAG=v3.1.0-qs11; run_case failure 'non-SG latest is rejected'; old_intact; no_stop
new_case; export TARGET_TAG=v3.1.0-sg1; run_case failure 'automatic downgrade is rejected'; old_intact; no_stop
new_case 3.1.0-sg3; run_case success 'same version refreshes menus without restarting'; no_stop
grep -q new-sg-menu "$XUI_CLI_PATH"
[[ $("$XUI_MAIN_FOLDER/x-ui" -v) == 3.1.0-sg3 && $(cat "$XUI_DB_FOLDER/x-ui.db") == original-db ]]
new_case 3.1.0-sg3; export FAIL_REPLACE=1; run_case failure 'same-version menu failure rolls back without touching binary or database'; no_stop
[[ $(cat "$XUI_CLI_PATH") == old-cli && $(cat "$XUI_MAIN_FOLDER/x-ui.sh") == old-menu ]]
[[ $("$XUI_MAIN_FOLDER/x-ui" -v) == 3.1.0-sg3 && $(cat "$XUI_DB_FOLDER/x-ui.db") == original-db ]]
new_case; echo stopped > "$XUI_UPDATE_STATE_DIR/service-state"; run_case success 'stopped service stays stopped'
[[ $(cat "$XUI_UPDATE_STATE_DIR/service-state") == stopped ]]
new_case; export EXPECT_EXISTING_LOCK=1; mkdir "$XUI_UPDATE_STATE_DIR/lock"; run_case failure 'concurrent updater is blocked'; old_intact; no_stop
new_case; export TEST_DB_TYPE=postgres FAIL_START=1; run_case failure 'PostgreSQL startup failure restores database'; old_intact
[[ -f "$XUI_UPDATE_STATE_DIR/postgres-restored" ]]
new_case; export TEST_DB_TYPE=postgres; run_case success 'PostgreSQL database is backed up before update'
[[ $(find "$XUI_BACKUP_DIR" -name database.dump | wc -l) == 1 ]]
new_case; export TEST_DB_TYPE=postgres FAIL_PG_DUMP=1; run_case failure 'PostgreSQL backup failure prevents replacement'; old_intact
new_case; export SIGNAL_UPDATE=1; run_case failure 'termination during replacement restores original installation'; old_intact
new_case; export WRAPPER_TEST=update; run_case success 'management launcher forwards channel and version'
[[ $(cat "$XUI_UPDATE_STATE_DIR/arguments") == $'sg\nv3.1.0-sg3' ]]; no_stop
new_case; export WRAPPER_TEST=menu; run_case success 'Update Menu stays on SG and backs up old menu'
grep -q new-sg-menu "$XUI_CLI_PATH"
[[ $(cat "$XUI_CLI_PATH.before-sg-menu") == old-cli ]]; no_stop
new_case; export WRAPPER_TEST=install; run_case success 'installer routes existing panel to the requested SG upgrade'
[[ $(cat "$XUI_UPDATE_STATE_DIR/arguments") == $'sg\nv3.1.0-sg3' ]]; old_intact; no_stop
new_case; export WRAPPER_TEST=install-default; run_case success 'installer defaults existing panels to latest SG without reinstall'
[[ $(cat "$XUI_UPDATE_STATE_DIR/arguments") == sg ]]; old_intact; no_stop
new_case
mkdir -p "$FIXTURE_ROOT/wrong/x-ui"
printf '#!/bin/sh\nprintf "3.1.0-sg99\\n"\n' > "$FIXTURE_ROOT/wrong/x-ui/x-ui"
(cd "$FIXTURE_ROOT/wrong" && tar -czf ../wrong.tar.gz x-ui)
(cd "$FIXTURE_ROOT" && sha256sum wrong.tar.gz | sed 's/wrong.tar.gz/x-ui-linux-amd64.tar.gz/' > wrong.sha256)
export ASSET_FILE=wrong.tar.gz HASH_FILE=wrong.sha256
run_case failure 'checksum-valid package with wrong embedded version is rejected'; old_intact; no_stop
new_case
mkdir -p "$FIXTURE_ROOT/link/x-ui"
mkdir "$FIXTURE_ROOT/link/x-ui/x-ui"
(cd "$FIXTURE_ROOT/link" && tar -czf ../link.tar.gz x-ui)
(cd "$FIXTURE_ROOT" && sha256sum link.tar.gz | sed 's/link.tar.gz/x-ui-linux-amd64.tar.gz/' > link.sha256)
export ASSET_FILE=link.tar.gz HASH_FILE=link.sha256
run_case failure 'non-regular executable in package is rejected'; old_intact; no_stop
new_case; export OFFICIAL_TEST=1
printf 'n\n' | "$shell" "$suite/worker.sh" > "$XUI_UPDATE_STATE_DIR/result.log" 2>&1
[[ ! -f "$XUI_UPDATE_STATE_DIR/official-called" ]]; old_intact
echo 'PASS: official migration requires explicit confirmation'
printf 'y\n' | "$shell" "$suite/worker.sh" > "$XUI_UPDATE_STATE_DIR/result.log" 2>&1
[[ -f "$XUI_UPDATE_STATE_DIR/official-called" ]]; echo 'PASS: official choice invokes only the official updater'
source "$UPDATER"
[[ $(printf '\n' | sg_select_channel 2>/dev/null) == sg ]]
[[ $(printf '2\n' | sg_select_channel 2>/dev/null) == official ]]
[[ $(printf '0\n' | sg_select_channel 2>/dev/null) == cancel ]]
if printf 'invalid\n' | sg_select_channel >/dev/null 2>&1; then exit 1; fi
echo 'PASS: menu default, official, cancel and invalid-input routing'
sg_db_folder='' sg_db_type='' sg_db_dsn=''
sg_read_db_setting 'XUI_DB_FOLDER="/custom folder/db"'
[[ $sg_db_folder == '/custom folder/db' ]]
sg_read_db_setting 'XUI_DB_TYPE=postgres'
[[ $sg_db_type == postgres ]]
sg_read_db_setting 'XUI_DB_DSN="postgres://example/db?sslmode=disable"'
[[ $sg_db_dsn == 'postgres://example/db?sslmode=disable' ]]
sg_read_db_setting 'OTHER_SETTING=$(touch unexpected-file)'
[[ ! -e unexpected-file ]]
echo 'PASS: database settings are read as data without executing configuration'
new_case
sg_manager=systemd sg_install=$XUI_MAIN_FOLDER sg_backup=$XUI_BACKUP_DIR
mkdir -p "$sg_backup"
MOCK_ENV_FILES='/custom/x-ui.env (ignore_errors=yes)' MOCK_DIRECT_ENV=''
systemctl() {
    local arg
    for arg in "$@"; do
        [[ "$arg" != --value ]] || { echo 'systemctl: unrecognized option --value' >&2; return 1; }
    done
    case "$3" in
        --property=MainPID) echo MainPID=0 ;;
        --property=EnvironmentFiles) echo "EnvironmentFiles=$MOCK_ENV_FILES" ;;
        --property=Environment) echo "Environment=$MOCK_DIRECT_ENV" ;;
        *) return 1 ;;
    esac
}
if sg_database_setup >/dev/null 2>&1; then echo 'Custom stopped configuration was not rejected' >&2; exit 1; fi
MOCK_ENV_FILES='' MOCK_DIRECT_ENV='XUI_DB_FOLDER=/unverified/database'
if sg_database_setup >/dev/null 2>&1; then echo 'Stopped database override was not rejected' >&2; exit 1; fi
MOCK_DIRECT_ENV=''
sg_database_setup
[[ $sg_db_type == sqlite && "$sg_db_file" == "$XUI_DB_FOLDER/x-ui.db" ]]
echo 'PASS: stopped services with unverified database overrides fail before mutation'
[[ $(sg_systemd_property MainPID) == 0 ]]
MOCK_DIRECT_ENV='XUI_DB_DSN="postgres://example/db?sslmode=disable&application_name=sg update"'
[[ $(sg_systemd_property Environment) == "$MOCK_DIRECT_ENV" ]]
MOCK_DIRECT_ENV=''
[[ -z $(sg_systemd_property Environment) ]]
echo 'PASS: legacy systemctl properties preserve empty values, spaces and equals signs without --value'
echo 'All SG update tests passed.'
