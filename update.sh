#!/usr/bin/env bash
# SG in-place updater. Only the panel binary and management scripts are replaced.
# Xray, geo files, certificates, service units and existing settings stay in place.

SG_REPO="ShiGuangDe/3x-ui-sg"

sg_log() { printf '%s\n' "$*"; }
sg_fail() { sg_log "更新失败：$*" >&2; return 1; }
sg_fetch() {
    curl --fail --location --show-error --silent --retry 3 --connect-timeout 20 \
        --max-time 1800 --proto '=https' --proto-redir '=https' "$@"
}
sg_valid_tag() { [[ "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-sg[0-9]+(\.[0-9]+)*$ ]]; }
sg_latest_tag() {
    local url tag
    url=$(sg_fetch --output /dev/null --write-out '%{url_effective}' "https://github.com/${SG_REPO}/releases/latest") || return 1
    tag=${url##*/}
    [[ "$url" == "https://github.com/${SG_REPO}/releases/tag/${tag}" ]] && sg_valid_tag "$tag" || return 1
    printf '%s\n' "$tag"
}
sg_arch() {
    case "$(uname -m)" in
        x86_64 | x64 | amd64) echo amd64 ;;
        i*86 | x86) echo 386 ;;
        aarch64 | arm64 | armv8*) echo arm64 ;;
        armv7* | arm) echo armv7 ;;
        armv6*) echo armv6 ;;
        armv5*) echo armv5 ;;
        s390x) echo s390x ;;
        *) sg_fail '不支持当前 CPU 架构。' ;;
    esac
}
sg_service_setup() {
    if [[ -d /run/systemd/system ]] && command -v systemctl >/dev/null; then
        sg_manager=systemd
    elif command -v rc-service >/dev/null; then
        sg_manager=openrc
    else
        sg_fail '需要 systemd 或 OpenRC 服务管理。Docker 请更新容器镜像。'
    fi
}
sg_service() {
    if [[ "$sg_manager" == systemd ]]; then
        case "$1" in
            active) systemctl is-active --quiet x-ui ;;
            *) systemctl "$1" x-ui ;;
        esac
    else
        case "$1" in
            active) rc-service x-ui status >/dev/null 2>&1 ;;
            *) rc-service x-ui "$1" ;;
        esac
    fi
}
# CentOS-era systemd does not implement --value. Read one NAME=value property
# and remove only its leading key, preserving spaces and '=' inside the value.
sg_systemd_property() {
    local property="$1" output
    output=$(systemctl show x-ui --property="$property") || return 1
    [[ "$output" == "$property="* ]] || { sg_fail '无法读取面板服务属性。'; return 1; }
    printf '%s\n' "${output#*=}"
}
sg_health() {
    local attempt stable=0
    for ((attempt = 0; attempt < 20; attempt++)); do
        sleep 1
        if sg_service active; then
            stable=$((stable + 1))
            [[ $stable -lt 5 ]] || return 0
        else
            stable=0
        fi
    done
    return 1
}
# Read only database settings; do not execute the contents of EnvironmentFile.
sg_read_db_setting() {
    local line="$1" value
    case "$line" in
        XUI_DB_FOLDER=* | XUI_DB_TYPE=* | XUI_DB_DSN=*)
            value=${line#*=}
            value=${value%$'\r'}
            if [[ "$value" == \"*\" || "$value" == \'*\' ]]; then value=${value:1:${#value}-2}; fi
            case "$line" in
                XUI_DB_FOLDER=*) sg_db_folder=$value ;;
                XUI_DB_TYPE=*) sg_db_type=$value ;;
                XUI_DB_DSN=*) sg_db_dsn=$value ;;
            esac
            ;;
    esac
}
sg_database_setup() {
    sg_db_folder=${XUI_DB_FOLDER:-/etc/x-ui}
    sg_db_type=${XUI_DB_TYPE:-sqlite}
    sg_db_dsn=${XUI_DB_DSN:-}
    local env_file='' line pid environment_files direct_environment live_environment=0
    if [[ "$sg_manager" == systemd ]]; then
        pid=$(sg_systemd_property MainPID) || return 1
        environment_files=$(sg_systemd_property EnvironmentFiles) || return 1
        if [[ -n "$environment_files" ]]; then
            if [[ "$environment_files" =~ ^(/etc/(default|conf.d|sysconfig)/x-ui)[[:space:]]+\(ignore_errors=(yes|no)\)$ ]]; then
                env_file=${BASH_REMATCH[1]}
            elif [[ ! "$pid" =~ ^[1-9][0-9]*$ || ! -r "/proc/${pid}/environ" ]]; then
                sg_fail '停止的服务使用自定义 EnvironmentFile；请先启动旧版面板，再运行更新以核实数据库位置。'
                return 1
            fi
        fi
        direct_environment=$(sg_systemd_property Environment) || return 1
        if [[ "$direct_environment" == *XUI_DB_* && ( ! "$pid" =~ ^[1-9][0-9]*$ || ! -r "/proc/${pid}/environ" ) ]]; then
            sg_fail '停止的服务存在数据库环境覆盖；请先启动旧版面板，再运行更新以核实数据库位置。'
            return 1
        fi
    else
        pid=$(cat /run/x-ui.pid 2>/dev/null || true)
        env_file=/etc/conf.d/x-ui
    fi
    if [[ "$pid" =~ ^[1-9][0-9]*$ && -r "/proc/${pid}/environ" ]]; then live_environment=1; fi
    if [[ -n "$env_file" && -f "$env_file" ]]; then
        if [[ "$live_environment" == 0 ]]; then
            while IFS= read -r line || [[ -n "$line" ]]; do sg_read_db_setting "$line"; done < "$env_file"
        fi
        cp -a -- "$env_file" "$sg_backup/environment"
    fi
    # The running process also covers custom systemd overrides and DB locations.
    if [[ "$live_environment" == 1 ]]; then
        sg_db_folder=/etc/x-ui sg_db_type=sqlite sg_db_dsn=''
        while IFS= read -r -d '' line; do sg_read_db_setting "$line"; done < "/proc/${pid}/environ"
    fi
    case "${sg_db_type,,}" in
        postgres | postgresql | pg)
            sg_db_type=postgres
            [[ -n "$sg_db_dsn" ]] || { sg_fail '未找到 PostgreSQL 连接配置。'; return 1; }
            command -v pg_dump >/dev/null && command -v pg_restore >/dev/null || {
                sg_fail 'PostgreSQL 更新需要已有的 pg_dump、pg_restore，暂未更改程序。'; return 1;
            }
            ;;
        sqlite | '')
            sg_db_type=sqlite
            [[ "$sg_db_folder" == /* ]] || sg_db_folder="$sg_install/$sg_db_folder"
            sg_db_file="$sg_db_folder/x-ui.db"
            [[ -f "$sg_db_file" ]] || { sg_fail '未找到原 SQLite 数据库，拒绝创建空数据库。'; return 1; }
            sg_db_file=$(readlink -f -- "$sg_db_file") || return 1
            ;;
        *) sg_fail '无法识别数据库类型。'; return 1 ;;
    esac
}
sg_backup_database() {
    if [[ "$sg_db_type" == postgres ]]; then
        PGDATABASE="$sg_db_dsn" pg_dump --format=custom --file="$sg_backup/database.dump"
    else
        local suffix
        for suffix in '' -wal -shm; do
            if [[ -e "${sg_db_file}${suffix}" ]]; then cp -a -- "${sg_db_file}${suffix}" "$sg_backup/x-ui.db${suffix}"; fi
        done
    fi
}
sg_restore_database() {
    if [[ "$sg_db_type" == postgres ]]; then
        pg_restore --clean --if-exists --exit-on-error --single-transaction --no-owner \
            --dbname="$sg_db_dsn" "$sg_backup/database.dump"
    else
        local suffix
        for suffix in '' -wal -shm; do
            if [[ -f "$sg_backup/x-ui.db${suffix}" ]]; then
                cp -a -- "$sg_backup/x-ui.db${suffix}" "${sg_db_file}${suffix}" || return 1
            elif [[ -n "$suffix" ]]; then
                rm -f -- "${sg_db_file}${suffix}" || return 1
            fi
        done
    fi
}
sg_atomic_install() {
    local source="$1" destination="$2" staging
    staging=$(mktemp "${destination}.sg-update.XXXXXX")
    sg_pending+=("$staging")
    cp -- "$source" "$staging"
    chmod 755 "$staging"
    mv -f -- "$staging" "$destination"
}
sg_rollback() {
    sg_log "启动或替换失败，正在恢复更新前的程序和数据库……" >&2
    if [[ "$sg_menu_only" == 0 ]]; then
        sg_service stop || { sg_fail "无法停止服务。备份保存在 $sg_backup，请勿在运行中恢复数据库。"; return 1; }
    fi
    local i destination
    for i in "${!sg_targets[@]}"; do
        destination=${sg_targets[$i]}
        if [[ -e "$sg_backup/program-$i" || -L "$sg_backup/program-$i" ]]; then
            cp -a -- "$sg_backup/program-$i" "${destination}.sg-restore.$$" && \
                mv -f -- "${destination}.sg-restore.$$" "$destination" || return 1
        else
            rm -f -- "$destination" || return 1
        fi
    done
    if [[ "$sg_menu_only" == 0 ]]; then
        sg_restore_database || { sg_fail "数据库恢复失败，备份保存在 $sg_backup。"; return 1; }
    fi
    if [[ "$sg_was_running" == 1 ]]; then
        sg_service start && sg_health || { sg_fail "旧版也未能启动，请检查服务日志。备份：$sg_backup"; return 1; }
    fi
    sg_log "已恢复更新前状态。备份：$sg_backup" >&2
}
sg_cleanup() {
    local status=$? pending
    trap - EXIT INT TERM HUP
    # Cleanup is best-effort: one failed cleanup must not prevent releasing our
    # lock. Bash 4.2 also treats an empty array as unset with set -u enabled.
    set +e
    if [[ "$sg_mutating" == 1 && "$status" != 0 ]]; then
        sg_rollback || sg_log '自动恢复未完成，请使用上面提示的备份排查。' >&2
    elif [[ "$sg_stopped" == 1 && "$sg_was_running" == 1 && "$status" != 0 ]]; then
        sg_service start || sg_log '原服务重启失败，请检查服务日志。' >&2
    fi
    for pending in "${sg_pending[@]-}"; do
        [[ -z "$pending" ]] || rm -f -- "$pending"
    done
    [[ -z "$sg_work" ]] || rm -rf -- "$sg_work"
    [[ "$sg_locked" == 0 ]] || rmdir -- "$sg_state/lock"
    exit "$status"
}
sg_update() (
    set -Eeuo pipefail
    umask 077
    sg_install=${XUI_MAIN_FOLDER:-/usr/local/x-ui}
    sg_install=${sg_install%/}
    sg_cli=${XUI_CLI_PATH:-/usr/bin/x-ui}
    sg_state=${XUI_UPDATE_STATE_DIR:-/var/lib/x-ui-sg-update}
    sg_backups=${XUI_BACKUP_DIR:-/var/backups/x-ui-sg}
    sg_work='' sg_backup='' sg_locked=0 sg_mutating=0 sg_stopped=0 sg_was_running=0 sg_menu_only=0
    sg_pending=() sg_targets=("$sg_install/x-ui" "$sg_install/x-ui.sh" "$sg_cli")
    [[ "$sg_install" == /* && -x "$sg_install/x-ui" ]] || { sg_fail '未找到已安装的面板，请先安装。'; exit 1; }
    [[ "$sg_cli" == /* && -d "${sg_cli%/*}" && ! -d "$sg_cli" ]] || { sg_fail '管理命令路径无效。'; exit 1; }
    mkdir -p -- "$sg_state" "$sg_backups"
    chmod 700 "$sg_state" "$sg_backups"
    mkdir -- "$sg_state/lock" 2>/dev/null || { sg_fail "已有更新在运行，或存在未清理的锁：$sg_state/lock"; exit 1; }
    sg_locked=1
    trap sg_cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM HUP
    local tag=${1:-} current arch asset expected version member i
    [[ -n "$tag" ]] || tag=$(sg_latest_tag)
    sg_valid_tag "$tag" || { sg_fail '只接受本仓库的 SG 正式版本号。'; exit 1; }
    current=$("$sg_install/x-ui" -v)
    current=${current#v}
    if [[ "$current" == "${tag#v}" ]]; then
        sg_menu_only=1
        sg_targets=("$sg_install/x-ui.sh" "$sg_cli")
        sg_work=$(mktemp -d "$sg_state/work.XXXXXX")
        sg_fetch --output "$sg_work/menu.sh" "https://raw.githubusercontent.com/$SG_REPO/main/x-ui.sh"
        bash -n "$sg_work/menu.sh"
        sg_backup=$(mktemp -d "$sg_backups/menu-$(date +%Y%m%d-%H%M%S).XXXXXX")
        for i in "${!sg_targets[@]}"; do
            if [[ -e "${sg_targets[$i]}" || -L "${sg_targets[$i]}" ]]; then cp -a -- "${sg_targets[$i]}" "$sg_backup/program-$i"; fi
        done
        sg_mutating=1
        sg_atomic_install "$sg_work/menu.sh" "$sg_install/x-ui.sh"
        sg_atomic_install "$sg_work/menu.sh" "$sg_cli"
        sg_mutating=0
        sg_log "面板已经是 $tag，已同步新版 SG 管理菜单，无需重启。备份：$sg_backup"
        exit 0
    fi
    # Prevent an accidentally retagged Latest release from silently downgrading SG.
    if sg_valid_tag "v$current" && [[ "$(printf '%s\n' "$current" "${tag#v}" | sort -V | head -n 1)" != "$current" ]]; then
        sg_fail "目标 $tag 比当前版本旧，拒绝自动降级。"; exit 1
    fi
    sg_service_setup
    arch=$(sg_arch)
    asset="x-ui-linux-${arch}.tar.gz"
    sg_work=$(mktemp -d "$sg_state/work.XXXXXX")
    sg_log "下载 SG 定制版 $tag（$arch），此时服务继续运行……"
    sg_fetch --output "$sg_work/$asset" "https://github.com/$SG_REPO/releases/download/$tag/$asset"
    sg_fetch --output "$sg_work/SHA256SUMS" "https://github.com/$SG_REPO/releases/download/$tag/SHA256SUMS"
    expected=$(awk -v name="$asset" '$2 == name || $2 == "*" name {print $1}' "$sg_work/SHA256SUMS")
    [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || { sg_fail '校验文件缺少此架构，或存在重复记录。'; exit 1; }
    if ! (cd "$sg_work" && printf '%s  %s\n' "$expected" "$asset" | sha256sum --check --status); then
        sg_fail '安装包 SHA256 校验失败，未更改程序。'; exit 1
    fi
    # Extract only the regular binary we replace; never unpack over the installation.
    if ! tar -tvzf "$sg_work/$asset" x-ui/x-ui | awk 'substr($1,1,1) != "-" {exit 1}'; then
        sg_fail '安装包中的面板文件不是普通文件，未更改程序。'; exit 1
    fi
    mkdir "$sg_work/staged"
    tar -xzf "$sg_work/$asset" -C "$sg_work/staged" x-ui/x-ui
    for member in x-ui; do
        [[ -f "$sg_work/staged/x-ui/$member" && ! -L "$sg_work/staged/x-ui/$member" ]] || exit 1
    done
    chmod 755 "$sg_work/staged/x-ui/x-ui"
    version=$("$sg_work/staged/x-ui/x-ui" -v)
    [[ "${version#v}" == "${tag#v}" ]] || { sg_fail '安装包内的版本号与发布版本不一致。'; exit 1; }
    # Management scripts follow this repository's main so old sg1/sg2 packages
    # cannot restore their obsolete, official-only update menu.
    sg_fetch --output "$sg_work/menu.sh" "https://raw.githubusercontent.com/$SG_REPO/main/x-ui.sh"
    bash -n "$sg_work/menu.sh"
    sg_backup=$(mktemp -d "$sg_backups/${tag}-$(date +%Y%m%d-%H%M%S).XXXXXX")
    printf 'from=%s\nto=%s\n' "$current" "$tag" > "$sg_backup/versions"
    for i in "${!sg_targets[@]}"; do
        if [[ -e "${sg_targets[$i]}" || -L "${sg_targets[$i]}" ]]; then cp -a -- "${sg_targets[$i]}" "$sg_backup/program-$i"; fi
    done
    sg_database_setup
    if sg_service active; then
        sg_was_running=1
        sg_stopped=1
        sg_service stop
    fi
    sg_backup_database
    sg_mutating=1
    sg_atomic_install "$sg_work/staged/x-ui/x-ui" "$sg_install/x-ui"
    sg_atomic_install "$sg_work/menu.sh" "$sg_install/x-ui.sh"
    sg_atomic_install "$sg_work/menu.sh" "$sg_cli"
    if [[ "$sg_was_running" == 1 ]]; then sg_service start; sg_health; fi
    sg_mutating=0
    sg_stopped=0
    sg_log "SG 覆盖更新完成：$tag。账号、节点、证书、端口与路径保持原配置。"
    [[ "$sg_was_running" == 1 ]] || sg_log '面板原来处于停止状态，更新后仍保持停止。'
    sg_log "更新前备份（请妥善保管）：$sg_backup"
)
sg_official() (
    set -euo pipefail
    umask 077
    local answer work state
    sg_log '此选项会退出 SG 定制版，覆盖为 MHSanaei/3x-ui 官方最新版，定制功能将被替换。'
    read -r -p '确认切换到官方版？[y/N]: ' answer || return 1
    [[ "$answer" == y || "$answer" == Y ]] || { sg_log '已取消。'; return 0; }
    state=${XUI_UPDATE_STATE_DIR:-/var/lib/x-ui-sg-update}
    mkdir -p "$state"
    chmod 700 "$state"
    mkdir "$state/lock" 2>/dev/null || { sg_fail '已有更新在运行。'; return 1; }
    work=''
    trap '[[ -z "$work" ]] || rm -rf -- "$work"; rmdir -- "$state/lock"' EXIT
    work=$(mktemp -d "$state/official.XXXXXX")
    sg_fetch --output "$work/update.sh" 'https://raw.githubusercontent.com/MHSanaei/3x-ui/main/update.sh'
    bash -n "$work/update.sh"
    bash "$work/update.sh"
)
sg_select_channel() {
    local choice
    sg_log '请选择更新渠道：' >&2
    sg_log '  1. SG 定制版最新正式版（保留数据，备份后覆盖更新）' >&2
    sg_log '  2. 官方 MHSanaei/3x-ui 最新版（退出 SG 定制版）' >&2
    sg_log '  0. 取消' >&2
    read -r -p '选择 [默认 1]: ' choice || return 1
    case "${choice:-1}" in
        1) echo sg ;;
        2) echo official ;;
        0) echo cancel ;;
        *) sg_fail '无效选项，未执行更新。'; return 1 ;;
    esac
}
sg_main() {
    local channel=${1:-} tag=${2:-}
    if [[ "$channel" == --help || "$channel" == -h ]]; then
        sg_log '用法：bash update.sh [sg [v版本号] | official]；不带参数显示双通道菜单。'
        return 0
    fi
    [[ $EUID == 0 ]] || { sg_fail '请使用 root 运行。'; return 1; }
    command -v curl >/dev/null || { sg_fail '需要 curl。'; return 1; }
    if [[ -z "$channel" ]]; then
        channel=$(sg_select_channel) || return 1
    fi
    case "$channel" in
        sg | --sg) sg_update "$tag" ;;
        official | --official) sg_official ;;
        cancel) return 0 ;;
        *) sg_fail '未知更新渠道，请运行 bash update.sh --help。'; return 1 ;;
    esac
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then sg_main "$@"; fi
