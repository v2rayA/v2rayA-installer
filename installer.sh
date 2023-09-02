#!/usr/bin/env sh

# shellcheck disable=SC2039

# set -x

## Color
if command -v tput > /dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RESET=$(tput sgr0)
fi

## Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "${RED}Error: This script must be run as root!${RESET}" >&2
    exit 1
fi

## Check curl, unzip
if ! command -v curl > /dev/null 2>&1; then
    tool_need_install="$tool_need_install""curl"
fi
if ! command -v unzip > /dev/null 2>&1; then
    tool_need_install="$tool_need_install ""unzip"
fi
if [ "$tool_need_install" != "" ]; then
    if command -v apt > /dev/null 2>&1; then
        apt update && apt install -y "$tool_need_install"
    elif command -v yum > /dev/null 2>&1; then
        yum install -y "$tool_need_install"
    elif command -v dnf > /dev/null 2>&1; then
        dnf install -y "$tool_need_install"
    elif command -v zypper > /dev/null 2>&1; then
        zypper --non-interactive install "$tool_need_install"
    elif command -v pacman > /dev/null 2>&1; then
        pacman -S --noconfirm "$tool_need_install"
    elif command -v apk > /dev/null 2>&1; then
        apk add "$tool_need_install"
    else
        echo "${RED}Error: Please install $tool_need_install then try again!${RESET}" >&2
        exit 1
    fi
fi

## Check OS and arch
if [ "$(uname -s)" != "Linux" ]; then
    echo "${RED}Error: This script only support Linux!${RESET}" >&2
    exit 1
fi
case "$(uname -m)" in
    x86_64)
        v2ray_arch="64"
        v2raya_arch="x64"
        ;;
    armv7l)
        v2ray_arch="arm32-v7a"
        v2raya_arch="armv7"
        ;;
    aarch64)
        v2ray_arch="arm64-v8a"
        v2raya_arch="arm64"
        ;;
    riscv64)
        v2ray_arch="riscv64"
        v2raya_arch="riscv64"
        ;;
    *)
        echo "${RED}Error: This script only support x86_64/armv7l/aarch64/riscv64 at the monment!${RESET}" >&2
        echo "${RED}Error: Please install v2ray and v2rayA manually!${RESET}" >&2
        exit 1
        ;;
esac

## Check version
check_v2ray_local_version() {
    if [ -f "/usr/local/bin/v2ray" ]; then
        v2ray_local_version=v$(/usr/local/bin/v2ray version | head -n 1 | cut -d " " -f2)
    else
        v2ray_local_version="0"
    fi
}
check_v2ray_remote_version() {
    v2ray_temp_file="$(mktemp /tmp/v2ray.XXXXXX)"
    if ! curl -s -I "https://github.com/v2fly/v2ray-core/releases/latest" > "$v2ray_temp_file"; then
        echo "${RED}Error: Cannot get latest version of v2ray!${RESET}" >&2
        exit 1
    fi
    v2ray_remote_version=$(grep -i ^location: "$v2ray_temp_file" | awk '{print $2}' | tr -d '\r' | awk -F 'tag/' '{print $2}')
    v2ray_url="https://github.com/v2fly/v2ray-core/releases/download/$v2ray_remote_version/v2ray-linux-$v2ray_arch.zip"
    rm -f "$v2ray_temp_file"
}
check_xray_local_version() {
    if [ -f "/usr/local/bin/xray" ]; then
        xray_local_version=v$(/usr/local/bin/xray version | head -n 1 | cut -d " " -f2)
    else
        xray_local_version="0"
    fi
}
check_xray_remote_version() {
    xray_temp_file="$(mktemp /tmp/xray.XXXXXX)"
    if ! curl -s -I "https://github.com/XTLS/Xray-core/releases/latest" > "$xray_temp_file"; then
        echo "${RED}Error: Cannot get latest version of xray!${RESET}" >&2
        exit 1
    fi
    xray_remote_version=$(grep -i ^location: "$xray_temp_file" | awk '{print $2}' | tr -d '\r' | awk -F 'tag/' '{print $2}')
    xray_url="https://github.com/XTLS/Xray-core/releases/download/$xray_remote_version/Xray-linux-$v2ray_arch.zip"
    rm -f "$xray_temp_file"
}
check_v2raya_local_version(){
    if [ -f "/usr/local/bin/v2raya" ]; then
        v2raya_local_version=v$(/usr/local/bin/v2raya --version | head -n 1 | cut -d " " -f2)
    else
        v2raya_local_version="0"
    fi
}
check_v2raya_remote_version(){
    v2raya_temp_file="$(mktemp /tmp/v2raya.XXXXXX)"
    if ! curl -s -I "https://github.com/v2rayA/v2rayA/releases/latest" > "$v2raya_temp_file"; then
        echo "${RED}Error: Cannot get latest version of v2rayA!${RESET}" >&2
        exit 1
    fi
    v2raya_remote_version=$(grep -i ^location: "$v2raya_temp_file" | awk '{print $2}' | tr -d '\r' | awk -F 'tag/' '{print $2}')
    v2raya_short_version=$(echo "$v2raya_remote_version" | cut -d "v" -f2)
    v2raya_url="https://github.com/v2rayA/v2rayA/releases/download/${v2raya_remote_version}/v2raya_linux_${v2raya_arch}_${v2raya_short_version}"
    rm -f "$v2raya_temp_file"
}

## Compare version
compare_v2ray_version() {
    if [ "$v2ray_local_version" = "0" ]; then
        echo "${YELLOW}Warning: v2ray not installed, installing v2ray version $v2ray_remote_version${RESET}" 
        download_v2ray="yes"
    elif [ "$v2ray_local_version" = "$v2ray_remote_version" ]; then
        echo "${GREEN}v2ray is up to date, version $v2ray_remote_version${RESET}" 
    else
        echo "${YELLOW}v2ray is not up to date, upgrading v2ray version $v2ray_local_version to version $v2ray_remote_version${RESET}"
        download_v2ray="yes"
    fi
}
compare_xray_version() {
    if [ "$xray_local_version" = "0" ]; then
        echo "${YELLOW}Warning: xray not installed, installing xray version $xray_remote_version${RESET}"
        download_xray="yes"
    elif [ "$xray_local_version" = "$xray_remote_version" ]; then
        echo "${GREEN}xray is up to date, version $xray_remote_version${RESET}" 
    else
        echo "${YELLOW}xray is not up to date, upgrading xray version $xray_local_version to version $xray_remote_version${RESET}"
        download_xray="yes"
    fi
}
compare_v2raya_version() {
    if [ "$v2raya_local_version" = "0" ]; then
        echo "${YELLOW}Warning: v2rayA not installed, installing v2rayA version $v2raya_remote_version${RESET}" 
        download_v2raya="yes"
    elif [ "$v2raya_local_version" = "$v2raya_remote_version" ]; then
        echo "${GREEN}v2rayA is up to date, version $v2raya_remote_version${RESET}" 
    else
        echo "${YELLOW}v2rayA is not up to date, upgrading v2rayA version $v2raya_local_version to version $v2raya_remote_version${RESET}" 
        download_v2raya="yes"
    fi
}

## Downloading
download_v2ray() {
    echo "${YELLOW}Downloading v2ray version $v2ray_remote_version${RESET}"
    echo "${GREEN}Downloading from $v2ray_url${RESET}"
    if ! curl -L -H "Cache-Control: no-cache" -o "/tmp/v2ray.zip" -# "$v2ray_url"; then
        echo "${RED}Error: Failed to download v2ray!${RESET}" >&2
        exit 1
    fi
}
download_xray() {
    echo "${GREEN}Downloading xray version $xray_remote_version${RESET}"
    echo "${GREEN}Downloading from $xray_url${RESET}"
    if ! curl -L -H "Cache-Control: no-cache" -o "/tmp/xray.zip" -# "$xray_url"; then
        echo "${RED}Error: Failed to download xray!${RESET}" >&2
        exit 1
    fi
}
download_v2raya() {
    echo "${GREEN}Downloading v2rayA version $v2raya_remote_version${RESET}"
    echo "${GREEN}Downloading from $v2raya_url${RESET}"
    if ! curl -L -H "Cache-Control: no-cache" -o "/tmp/v2raya" -# "$v2raya_url"; then
        echo "${RED}Error: Failed to download v2rayA!${RESET}" >&2
        exit 1
    fi
    if command -v systemctl > /dev/null 2>&1; then
        service_file_url="https://github.com/v2rayA/v2rayA-installer/raw/main/systemd/v2raya.service"
        echo "${GREEN}Downloading v2rayA service file${RESET}"
        echo "${GREEN}Downloading from $service_file_url${RESET}"
        if ! curl -L -H "Cache-Control: no-cache" -o "/tmp/v2raya.service" -# "$service_file_url"; then
            echo "${RED}Error: Failed to download v2rayA service file!${RESET}" >&2
            exit 1
        fi
    fi
    if command -v rc-service > /dev/null 2>&1; then
        service_script_url="https://github.com/v2rayA/v2rayA-installer/raw/main/openrc/v2raya"
        echo "${GREEN}Downloading v2rayA service file${RESET}"
        echo "${GREEN}Downloading from $service_script_url${RESET}"
        if ! curl -L -H "Cache-Control: no-cache" -o "/tmp/v2raya-openrc" -s "$service_script_url"; then
            echo "${RED}Error: Failed to download v2rayA service file!${RESET}" >&2
            exit 1
        fi
    fi
}

## Stop v2rayA service
stop_v2raya() {
    if [ -f "/etc/systemd/system/v2raya.service" ] && [ "$(systemctl is-active v2raya)" = active ]; then
        systemctl stop v2raya
        v2raya_stopped="yes"
    fi
    if [ -f /sbin/openrc-run ] && [ -f "/etc/init.d/v2raya" ] && [ "$(rc-service v2raya status | grep started | awk '{print $3}')" = started ]; then
        rc-service v2raya stop
        v2raya_stopped="yes"
    fi
}

## Installing
install_v2ray() {
    unzip -q /tmp/v2ray.zip -d /tmp/v2ray
    install /tmp/v2ray/v2ray /usr/local/bin/v2ray
    [ -d /usr/local/share/v2ray ] || mkdir -p /usr/local/share/v2ray
    mv /tmp/v2ray/geoip.dat /usr/local/share/v2ray/geoip.dat
    mv /tmp/v2ray/geosite.dat /usr/local/share/v2ray/geosite.dat
    rm -rf /tmp/v2ray.zip /tmp/v2ray
    echo "${GREEN}v2ray version $v2ray_remote_version installed successfully!${RESET}"
}
install_xray() {
    unzip -q /tmp/xray.zip -d /tmp/xray
    install /tmp/xray/xray /usr/local/bin/xray
    [ -d /usr/local/share/xray ] || mkdir -p /usr/local/share/xray
    mv /tmp/xray/geoip.dat /usr/local/share/xray/geoip.dat
    mv /tmp/xray/geosite.dat /usr/local/share/xray/geosite.dat
    rm -rf /tmp/xray.zip /tmp/xray
    echo "${GREEN}xray version $xray_remote_version installed successfully!${RESET}"
}
install_v2raya() {
    install /tmp/v2raya /usr/local/bin/v2raya
    if command -v systemctl > /dev/null 2>&1; then
        mv /tmp/v2raya.service /etc/systemd/system/v2raya.service
        systemctl daemon-reload
    elif command -v rc-service > /dev/null 2>&1; then
        install /tmp/v2raya-openrc /etc/init.d/v2raya
    else
        echo "${YELLOW}No service would be installed beacuse systemd/openrc not found on your system${RESET}"
    fi
    rm -f /tmp/v2raya 
    [ -f /tmp/v2raya.service ] && rm -f /tmp/v2raya.service || [ -f /tmp/v2raya-openrc ] && rm -f /tmp/v2raya-openrc
    echo "${GREEN}v2rayA version $v2raya_remote_version installed successfully!${RESET}"
}

## Start v2rayA service
start_v2raya() {
    if [ "$v2raya_stopped" = "yes" ]; then
        if [ -f "/etc/systemd/system/v2raya.service" ]; then
            systemctl start v2raya
        fi
        if [ -f /sbin/openrc-run ] && [ -f "/etc/init.d/v2raya" ]; then
            rc-service v2raya start
        fi
    fi
}

## Installation Flow
if [ "$1" = '' ] || [ "$1" = '--with-v2ray' ]; then
    check_v2ray_local_version
    check_v2ray_remote_version
    check_v2raya_local_version
    check_v2raya_remote_version
    compare_v2ray_version
    if [ "$download_v2ray" = "yes" ]; then
        download_v2ray
        install_v2ray_need="yes"
    fi
    compare_v2raya_version
    if [ "$download_v2raya" = "yes" ]; then
        download_v2raya
        install_v2raya_need="yes"
    fi
    if [ "$install_v2ray_need" = "yes" ] || [ "$install_v2raya_need" = yes ]; then
        stop_v2raya
        if [ "$install_v2ray_need" = "yes" ]; then
            install_v2ray
        fi
        if [ "$install_v2raya_need" = "yes" ]; then
            install_v2raya
        fi
        start_v2raya
    fi
fi
if [ "$1" = '--with-xray' ]; then
    check_xray_local_version
    check_xray_remote_version
    check_v2raya_local_version
    check_v2raya_remote_version
    compare_xray_version
    if [ "$download_xray" = "yes" ]; then
        download_xray
        install_xray_need="yes"
    fi
    compare_v2raya_version
    if [ "$download_v2raya" = "yes" ]; then
        download_v2raya
        install_v2raya_need="yes"
    fi
    if [ "$install_xray_need" = "yes" ] || [ "$install_v2raya_need" = yes ]; then
        stop_v2raya
        if [ "$install_xray_need" = "yes" ]; then
            install_xray
        fi
        if [ "$install_v2raya_need" = "yes" ]; then
            install_v2raya
        fi
        start_v2raya
    fi
fi
if [ "$1" != '' ] && [ "$1" != '--with-v2ray' ] && [ "$1" != '--with-xray' ]; then
    echo "${RED}Error: Invalid argument!${RESET}" >&2
    echo "${GREEN}Usage: installer.sh [--with-v2ray|--with-xray]${RESET}" >&2
    exit 1
fi
if [ "$(command -v systemctl)" ]; then
    echo "${GREEN}Start v2rayA service now:${RESET}" systemctl start v2raya
    echo "${GREEN}Auto start v2rayA service:${RESET}" systemctl enable v2raya
elif [ "$(command -v rc-service)" ]; then
    echo "${GREEN}Start v2rayA service now:${RESET}" rc-service v2raya start
    echo "${GREEN}Auto start v2rayA service:${RESET}" rc-update add v2raya
else
    echo "${YELLOW}systemd/openrc not found on your system, write and manage service by yourself.${RESET}"
fi
