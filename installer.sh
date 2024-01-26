#!/usr/bin/env sh

# shellcheck disable=SC2039

set -e

# Don't use anything from fucking Ubuntu Snap
PATH="$(echo "$PATH" | sed 's|:/snap/bin||g')"
export PATH

## Color
if command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RESET=$(tput sgr0)
fi

## SHA256SUM
if command -v sha256sum >/dev/null 2>&1; then
    SHA256SUM() {
        sha256sum "$1" | awk -F ' ' '{print$1}'
    }
elif command -v shasum >/dev/null 2>&1; then
    SHA256SUM() {
        shasum -a 256 "$1" | awk -F ' ' '{print$1}'
    }
elif command -v openssl >/dev/null 2>&1; then
    SHA256SUM() {
        openssl dgst -sha256 "$1" | awk -F ' ' '{print$2}'
    }
elif command -v busybox >/dev/null 2>&1; then
    SHA256SUM() {
        busybox sha256sum "$1" | awk -F ' ' '{print$1}'
    }
fi

## Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "${RED}Error: This script must be run as root!${RESET}" >&2
    exit 1
fi

## Check curl, unzip
for tool in curl unzip; do
    if ! command -v $tool >/dev/null 2>&1; then
        tool_need="$tool"" ""$tool_need"
    fi
done
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1 && ! command -v openssl >/dev/null 2>&1; then
    tool_need="openssl"" ""$tool_need"
fi
if [ -n "$tool_need" ]; then
    if command -v apt >/dev/null 2>&1; then
        command_install_tool="apt update; apt install $tool_need -y"
    elif command -v dnf >/dev/null 2>&1; then
        command_install_tool="dnf install $tool_need -y"
    elif command -v yum >/dev/null 2>&1; then
        command_install_tool="yum install $tool_need -y"
    elif command -v zypper >/dev/null 2>&1; then
        command_install_tool="zypper --non-interactive install $tool_need"
    elif command -v pacman >/dev/null 2>&1; then
        command_install_tool="pacman -Sy $tool_need --noconfirm"
    elif command -v apk >/dev/null 2>&1; then
        command_install_tool="apk add $tool_need"
    else
        echo "$RED""You should install ""$tool_need""then try again.""$RESET"
        exit 1
    fi
    if ! /bin/sh -c "$command_install_tool"; then
        echo "$RED""Use system package manager to install $tool_need failed,""$RESET"
        echo "$RED""You should install ""$tool_need""then try again.""$RESET"
        exit 1
    fi
fi
notice_installled_tool() {
    if [ -n "$tool_need" ]; then
        echo "${GREEN}You have installed the following tools during installation:${RESET}"
        echo "$tool_need"
        echo "${GREEN}You can uninstall them now if you want.${RESET}"
    fi
}

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
    if ! curl -s "https://api.github.com/repos/v2fly/v2ray-core/releases/latest" -o "$v2ray_temp_file"; then
        echo "${RED}Error: Cannot get latest version of v2ray!${RESET}"
        exit 1
    fi
    v2ray_remote_version=$(grep tag_name "$v2ray_temp_file" | awk -F '"' '{printf $4}')
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
    if ! curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" -o "$xray_temp_file"; then
        echo "${RED}Error: Cannot get latest version of xray!${RESET}"
        exit 1
    fi
    xray_remote_version=$(grep tag_name "$xray_temp_file" | awk -F '"' '{printf $4}')
    xray_url="https://github.com/XTLS/Xray-core/releases/download/$xray_remote_version/Xray-linux-$v2ray_arch.zip"
    rm -f "$xray_temp_file"
}
check_v2raya_local_version() {
    if [ -f "/usr/local/bin/v2raya" ]; then
        v2raya_local_version=v$(/usr/local/bin/v2raya --version | head -n 1 | cut -d " " -f2)
    else
        v2raya_local_version="0"
    fi
}
check_v2raya_remote_version() {
    v2raya_temp_file="$(mktemp "$v2ray_temp_file".XXXXXX)"
    if ! curl -s "https://api.github.com/repos/v2rayA/v2rayA/releases/latest" -o "$v2raya_temp_file"; then
        echo "${RED}Error: Cannot get latest version of v2rayA!${RESET}"
        exit 1
    fi
    v2raya_remote_version=$(grep tag_name "$v2raya_temp_file"| awk -F '"' '{printf $4}')
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
    elif [ "$(printf '%s\n' "$v2ray_local_version" "$v2ray_remote_version" | sort -rV | head -n1)" = "$v2ray_local_version" ]; then
        echo "${YELLOW}v2ray is not up to date, upgrading v2ray version $v2ray_local_version to version $v2ray_remote_version${RESET}"
        download_v2ray="yes"
    else
        echo "${YELLOW}Local v2ray version $v2ray_local_version is greater than remote version $v2ray_remote_version${RESET}"
    fi
}
compare_xray_version() {
    if [ "$xray_local_version" = "0" ]; then
        echo "${YELLOW}Warning: xray not installed, installing xray version $xray_remote_version${RESET}"
        download_xray="yes"
    elif [ "$xray_local_version" = "$xray_remote_version" ]; then
        echo "${GREEN}xray is up to date, version $xray_remote_version${RESET}"
    elif [ "$(printf '%s\n' "$xray_local_version" "$xray_remote_version" | sort -rV | head -n1)" = "$xray_local_version" ]; then
        echo "${YELLOW}xray is not up to date, upgrading xray version $xray_local_version to version $xray_remote_version${RESET}"
        download_xray="yes"
    else
        echo "${YELLOW}Local xray version $xray_local_version is greater than remote version $xray_remote_version${RESET}"
    fi
}
compare_v2raya_version() {
    if [ "$v2raya_local_version" = "0" ]; then
        echo "${YELLOW}Warning: v2rayA not installed, installing v2rayA version $v2raya_remote_version${RESET}"
        download_v2raya="yes"
    elif [ "$v2raya_local_version" = "$v2raya_remote_version" ]; then
        echo "${GREEN}v2rayA is up to date, version $v2raya_remote_version${RESET}"
    elif [ "$(printf '%s\n' "$v2raya_local_version" "$v2raya_remote_version" | sort -rV | head -n1)" = "$v2raya_local_version" ]; then
        echo "${YELLOW}v2rayA is not up to date, upgrading v2rayA version $v2raya_local_version to version $v2raya_remote_version${RESET}"
        download_v2raya="yes"
    else
        echo "${YELLOW}Local v2rayA version $v2raya_local_version is greater than remote version $v2raya_remote_version${RESET}"
    fi
}

## Downloading
download_v2ray() {
    v2ray_temp_file="$(mktemp -u)"
    echo "${GREEN}Downloading v2ray version $v2ray_remote_version${RESET}"
    echo "${GREEN}Downloading from $v2ray_url${RESET}"
    if ! curl -L -H "Cache-Control: no-cache" -o "$v2ray_temp_file" -# "$v2ray_url"; then
        echo "${RED}Error: Failed to download v2ray!${RESET}"
        exit 1
    fi
    if ! curl -L -H "Cache-Control: no-cache" -o "$v2ray_temp_file.dgst" -s "$v2ray_url".dgst; then
        echo "${RED}Error: Failed to download v2ray dgst!${RESET}"
        exit 1
    fi
    local_v2ray_hash="$(SHA256SUM "$v2ray_temp_file")"
    remote_v2ray_hash=$(awk -F '= ' '/256=/ {print $2}' <"$v2ray_temp_file".dgst)
    if [ "$local_v2ray_hash" != "$remote_v2ray_hash" ]; then
        echo "${RED}Error: v2ray hash value verification failed!${RESET}"
        echo "Expect: $remote_v2ray_hash"
        echo "Actually: $local_v2ray_hash"
        exit 1
    fi
}
download_xray() {
    xray_temp_file="$(mktemp -u)"
    echo "${GREEN}Downloading xray version $xray_remote_version${RESET}"
    echo "${GREEN}Downloading from $xray_url${RESET}"
    if ! curl -L -H "Cache-Control: no-cache" -o "$xray_temp_file" -# "$xray_url"; then
        echo "${RED}Error: Failed to download xray!${RESET}"
        exit 1
    fi
    if ! curl -L -H "Cache-Control: no-cache" -o "$xray_temp_file.dgst" -s "$xray_url".dgst; then
        echo "${RED}Error: Failed to download xray dgst!${RESET}"
        exit 1
    fi
    local_xray_hash="$(SHA256SUM "$xray_temp_file")"
    remote_xray_hash=$(awk -F '= ' '/256=/ {print $2}' <"$xray_temp_file".dgst)
    if [ "$local_xray_hash" != "$remote_xray_hash" ]; then
        echo "${RED}Error: xray hash value verification failed!${RESET}"
        echo "Expect: $remote_xray_hash"
        echo "Actually: $local_xray_hash"
        exit 1
    fi
}
download_v2raya() {
    v2raya_temp_file="$(mktemp -u)"
    echo "${GREEN}Downloading v2rayA version $v2raya_remote_version${RESET}"
    echo "${GREEN}Downloading from $v2raya_url${RESET}"
    if ! curl -L -H "Cache-Control: no-cache" -o "$v2raya_temp_file" -# "$v2raya_url"; then
        echo "${RED}Error: Failed to download v2rayA!${RESET}"
        exit 1
    fi
    if ! curl -L -H "Cache-Control: no-cache" -o "$v2raya_temp_file".sha256.txt -s "$v2raya_url".sha256.txt; then
        echo "${RED}Error: Failed to download v2rayA sha256 txt!${RESET}"
        exit 1
    fi
    local_v2raya_hash="$(SHA256SUM "$v2raya_temp_file")"
    remote_v2raya_hash=$(cat "$v2raya_temp_file".sha256.txt)
    if [ "$local_v2raya_hash" != "$remote_v2raya_hash" ]; then
        echo "${RED}Error: v2rayA hash value verification failed!${RESET}"
        echo "Expect: $remote_v2raya_hash"
        echo "Actually: $local_v2raya_hash"
        exit 1
    fi
    if command -v systemctl >/dev/null 2>&1; then
        service_file_url="https://github.com/v2rayA/v2rayA-installer/raw/main/systemd/v2raya.service"
        echo "${GREEN}Downloading v2rayA service file${RESET}"
        echo "${GREEN}Downloading from $service_file_url${RESET}"
        if ! curl -L -H "Cache-Control: no-cache" -o "$v2raya_temp_file".service -# "$service_file_url"; then
            echo "${RED}Error: Failed to download v2rayA service file!${RESET}"
            exit 1
        fi
    fi
    if command -v rc-service >/dev/null 2>&1; then
        service_script_url="https://github.com/v2rayA/v2rayA-installer/raw/main/openrc/v2raya"
        echo "${GREEN}Downloading v2rayA service file${RESET}"
        echo "${GREEN}Downloading from $service_script_url${RESET}"
        if ! curl -L -H "Cache-Control: no-cache" -o "$v2raya_temp_file"-openrc -s "$service_script_url"; then
            echo "${RED}Error: Failed to download v2rayA service file!${RESET}"
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
    unzip -q "$v2ray_temp_file" -d "$v2ray_temp_file"_unzipped
    install "$v2ray_temp_file"_unzipped/v2ray /usr/local/bin/v2ray
    [ -d /usr/local/share/v2ray ] || mkdir -p /usr/local/share/v2ray
    mv "$v2ray_temp_file"_unzipped/geoip.dat /usr/local/share/v2ray/geoip.dat
    mv "$v2ray_temp_file"_unzipped/geosite.dat /usr/local/share/v2ray/geosite.dat
    rm -rf "$v2ray_temp_file" "$v2ray_temp_file"_unzipped "$v2ray_temp_file".dgst
    echo "${GREEN}v2ray version $v2ray_remote_version installed successfully!${RESET}"
}
install_xray() {
    unzip -q "$xray_temp_file" -d "$xray_temp_file"_unzipped
    install "$xray_temp_file"_unzipped/xray /usr/local/bin/xray
    [ -d /usr/local/share/xray ] || mkdir -p /usr/local/share/xray
    mv "$xray_temp_file"_unzipped/geoip.dat /usr/local/share/xray/geoip.dat
    mv "$xray_temp_file"_unzipped/geosite.dat /usr/local/share/xray/geosite.dat
    rm -rf "$xray_temp_file" "$xray_temp_file"_unzipped "$xray_temp_file".dgst
    echo "${GREEN}xray version $xray_remote_version installed successfully!${RESET}"
}
install_v2raya() {
    install "$v2raya_temp_file" /usr/local/bin/v2raya
    if command -v systemctl >/dev/null 2>&1; then
        install -m 644 "$v2raya_temp_file".service /etc/systemd/system/v2raya.service
        systemctl daemon-reload
    elif command -v rc-service >/dev/null 2>&1; then
        install "$v2raya_temp_file"-openrc /etc/init.d/v2raya
    fi
    rm -f "$v2raya_temp_file" "$v2raya_temp_file".sha256.txt
    [ -f "$v2raya_temp_file".service ] && rm -f "$v2raya_temp_file".service || [ -f "$v2raya_temp_file"-openrc ] && rm -f "$v2raya_temp_file"-openrc
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

## Reset password script
set_reset_password_script() {
    echo '#!/bin/sh
if [ "$(id -u)" != 0 ]; then
    if command -v sudo > /dev/null 2>&1; then
        sudo v2raya -c /usr/local/etc/v2raya --reset-password
    fi
    if command -v doas > /dev/null 2>&1; then
        doas v2raya -c /usr/local/etc/v2raya --reset-password
    fi
elif [ "$(id -u)" = 0 ]; then
    v2raya -c /usr/local/etc/v2raya --reset-password
else
    echo "Error: This command must be run as root!"
fi' >/usr/local/bin/v2raya-reset-password
    chmod 755 /usr/local/bin/v2raya-reset-password
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
    set_reset_password_script
    notice_installled_tool
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
    set_reset_password_script
    notice_installled_tool
fi
if [ "$1" != '' ] && [ "$1" != '--with-v2ray' ] && [ "$1" != '--with-xray' ]; then
    echo "${RED}Error: Invalid argument!${RESET}" >&2
    echo "${GREEN}Usage: installer.sh [--with-v2ray|--with-xray]${RESET}" >&2
    exit 1
fi
if [ "$(command -v systemctl)" ]; then
    echo "${GREEN}"--------------------------------------------------------------------------------"${RESET}"
    echo "${GREEN}"Commands:"${RESET}"
    echo "${GREEN}Start v2rayA service now:${RESET}"
    echo "systemctl start v2raya"
    echo "${GREEN}Start v2rayA service at system boot:${RESET}"
    echo "systemctl enable v2raya"
elif [ "$(command -v rc-service)" ]; then
    echo "${GREEN}"--------------------------------------------------------------------------------"${RESET}"
    echo "${GREEN}"Commands:"${RESET}"
    echo "${GREEN}Start v2rayA service now:${RESET}"
    echo "rc-service v2raya start"
    echo "${GREEN}Start v2rayA service at system boot:${RESET}"
    echo "rc-update add v2raya"
else
    echo "${GREEN}"--------------------------------------------------------------------------------"${RESET}"
    echo "${YELLOW}systemd/openrc not found on your system, write and manage service by yourself.${RESET}"
fi

echo "${GREEN}"--------------------------------------------------------------------------------"${RESET}"
echo "1. v2rayA has been installed to your system, the configuration directory is
   /usr/local/etc/v2raya.
2. v2rayA will not start automatically, you can start it by yourself.
3. If you want to uninstall v2rayA, please run uninstaller.sh.
4. If you want to update v2rayA, please run installer.sh again.
5. Official website: https://v2raya.org.
6. If you forget your password, run \"v2raya-reset-password\" to reset it."
echo "${GREEN}"--------------------------------------------------------------------------------"${RESET}"
