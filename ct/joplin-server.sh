#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Slaviša Arežina (tremor021)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://joplinapp.org/

APP="Joplin Server"
var_tags="${var_tags:-notes}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-15}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /opt/joplin-server ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  RELEASE=$(curl -fsSL https://api.github.com/repos/laurent22/joplin/releases/latest | jq '.tag_name' | sed 's/^"v//;s/"$//')
  if check_for_gh_release "joplin-server" "laurent22/joplin"; then
    msg_info "Stopping Services"
    systemctl stop joplin-server
    msg_ok "Stopped Services"

    INSTALL_DIR="/opt/autocaliweb"
    export VIRTUAL_ENV="${INSTALL_DIR}/venv"
    $STD tar -cf ~/autocaliweb_bkp.tar "$INSTALL_DIR"/{metadata_change_logs,dirs.json,.env,scripts/ingest_watcher.sh,scripts/auto_zipper_wrapper.sh,scripts/metadata_change_detector_wrapper.sh}
    fetch_and_deploy_gh_release "autocaliweb" "gelbphoenix/autocaliweb" "tarball" "latest" "/opt/autocaliweb"
    msg_info "Updating ${APP}"
    cd "$INSTALL_DIR"
    if [[ ! -d "$VIRTUAL_ENV" ]]; then
      $STD uv venv "$VIRTUAL_ENV"
    fi
    $STD uv sync --all-extras --active
    cd "$INSTALL_DIR"/koreader/plugins
    PLUGIN_DIGEST="$(find acwsync.koplugin -type f -name "*.lua" -o -name "*.json" | sort | xargs sha256sum | sha256sum | cut -d' ' -f1)"
    echo "Plugin files digest: $PLUGIN_DIGEST" >acwsync.koplugin/${PLUGIN_DIGEST}.digest
    echo "Build date: $(date)" >>acwsync.koplugin/${PLUGIN_DIGEST}.digest
    echo "Files included:" >>acwsync.koplugin/${PLUGIN_DIGEST}.digest
    $STD zip -r koplugin.zip acwsync.koplugin/
    cp -r koplugin.zip "$INSTALL_DIR"/cps/static
    mkdir -p "$INSTALL_DIR"/metadata_temp
    $STD tar -xf ~/autocaliweb_bkp.tar --directory /
    KEPUB_VERSION="$(/usr/bin/kepubify --version)"
    CALIBRE_RELEASE="$(curl -s https://api.github.com/repos/kovidgoyal/calibre/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)"
    echo "${KEPUB_VERSION#v}" >"$INSTALL_DIR"/KEPUBIFY_RELEASE
    echo "${CALIBRE_RELEASE#v}" >/"$INSTALL_DIR"/CALIBRE_RELEASE
    sed 's/^/v/' ~/.autocaliweb >"$INSTALL_DIR"/ACW_RELEASE
    chown -R acw:acw "$INSTALL_DIR"
    rm ~/autocaliweb_bkp.tar
    msg_ok "Updated $APP"

    msg_info "Starting Services"
    systemctl start autocaliweb metadata-change-detector acw-ingest-service acw-auto-zipper
    msg_ok "Started Services"

    msg_ok "Updated Successfully"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8083${CL}"
