#!/usr/bin/env sh

# This script is used to remove v2rayA from your system.
# It is part of v2rayA's FHS installer.

if [ -f /etc/systemd/system/v2raya.service ];then
    systemctl disable v2raya --now
    rm -f /etc/systemd/system/v2raya.service
    rm -rf /etc/system/systemd/v2raya.service.d
    systemctl daemon-reload
fi

if [ -f /etc/init.d/v2raya ] && [ -f /sbin/openrc-run ];then
    rc-update del v2raya
    /etc/init.d/v2raya stop
    rm -f /etc/init.d/v2raya
    rm -f /etc/conf.d/v2raya
fi

rm -f /usr/local/bin/v2raya

echo "1. v2rayA has been removed from your system, but the configuration files
   are still there; the path is /usr/local//etc/v2raya. If you want to 
   remove them, you can delete them manually.
2. v2ray/xray has not been removed, beacuse they might not installed by
   this installer, you can remove them manually if you want."
