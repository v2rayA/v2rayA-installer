# v2rayA Linux installer

## Installation

Install with v2ray core:

```sh
sudo sh -c "$(wget -qO- https://raw.githubusercontent.com/v2rayA/v2rayA-installer/main/installer.sh)" @ --with-v2ray
```

Install with xray core:

```sh
sudo sh -c "$(wget -qO- https://raw.githubusercontent.com/v2rayA/v2rayA-installer/main/installer.sh)" @ --with-xray
```

Use `curl -Ls` to replace `wget -qO-` if you want to use curl instead of wget.

## Remove

```sh
sudo sh -c "$(wget -qO- https://raw.githubusercontent.com/v2rayA/v2rayA-installer/main/uninstaller.sh)"
```
