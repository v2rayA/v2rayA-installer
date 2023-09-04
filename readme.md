# v2rayA Linux installer

## Usage

### Install v2rayA

Install with v2ray core:

```sh
sudo sh -c "$(wget -qO- https://github.com/v2rayA/v2rayA-installer/raw/main/installer.sh)" @ --with-v2ray
```

Install with xray core:

```sh
sudo sh -c "$(wget -qO- https://github.com/v2rayA/v2rayA-installer/raw/main/installer.sh)" @ --with-xray
```

Use `curl -Ls` to replace `wget -qO-` if you want to use curl instead of wget.

### Remove v2rayA

```sh
sudo sh -c "$(wget -qO- https://github.com/v2rayA/v2rayA-installer/raw/main/uninstaller.sh)"
```

## Service file

### Systemd

See [systemd](./systemd/)

### OpenRC

See [openrc](./openrc/)

### Classic SysV

```sh
#!/bin/sh 
# chkconfig: 2345 99 01

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
v2rayA_bin=/usr/local/bin/v2raya
pid_file=/run/v2raya.pid

if [ ! -d "/tmp/v2raya/" ]; then 
    mkdir "/tmp/v2raya" 
fi
if [ ! -d "/var/log/v2raya/" ]; then
    ln -s "/tmp/v2raya/" "/var/log/"
fi

export V2RAYA_CONFIG="/usr/local/etc/v2raya"
export V2RAYA_LOG_FILE="/tmp/v2raya/v2raya.log"

START() {
    start-stop-daemon -S -b -p $pid_file -m -x $v2rayA_bin
}

STOP() {
    start-stop-daemon -K -p $pid_file && rm $pid_file
}

case "$1" in
    start)
        echo "Starting V2raya..."
        START
        echo "v2rayA started"
        ;;

    stop)
        echo "Stopping V2raya..."
        STOP
        echo "v2rayA stopprd"
        ;;

    restart)
        echo "Restarting V2raya..."
        STOP
        sleep 3
        START
        echo "v2rayA restarted"
        ;;

    log)
        echo "Displaying V2raya Logs..."
        tail -f /var/log/v2raya/v2raya.log
        ;;
esac
exit 0
```