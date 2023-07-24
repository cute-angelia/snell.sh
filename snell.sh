#!/usr/bin/env bash

# 判断系统版本
SYSTEM=$(cat /etc/issue | cut -d ' ' -f 1)

if [[ ${SYSTEM} == "CentOS" ]]; then
  SERVICE_DIR=/etc/systemd/system
  SYSTEMCTL=systemctl
  yum install unzip -y
elif [[ ${SYSTEM} == "Debian" ]]; then
  SERVICE_DIR=/lib/systemd/system
  SYSTEMCTL=service
  apt-get install unzip -y
elif [[ ${SYSTEM} == "Ubuntu" ]]; then
  SERVICE_DIR=/lib/systemd/system
  SYSTEMCTL=systemctl  
  apt-get install unzip -y
else
  echo "Unrecognized system version"
  exit 1
fi

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
CONF="/etc/snell/snell-server.conf"
SYSTEMD=${SERVICE_DIR}/snell.service
 
# cpu
OS=$(uname -s)
ARCH=$(uname -m)

if [ "$OS" = "Linux" ]; then

  if [ "$ARCH" = "x86_64" ]; then
    PLAT="linux-amd64"
  elif [ "$ARCH" = "aarch64" ]; then
    PLAT="linux-arm64"
  else
    echo "Unsupported architecture $ARCH"
    exit 1
  fi

elif [ "$OS" = "Darwin" ]; then
  PLAT="darwin-amd64"

else
  echo "Unsupported OS $OS"
  exit 1
fi

URL="https://github.com/cute-angelia/open-snell/releases/download/v3.0.1/snell-server-$PLAT.zip"

# 下载和安装
cd ~/
wget --no-check-certificate -O snell.zip $URL
unzip -o snell.zip

 rm -f snell.zip
 chmod +x snell-server
 mv -f snell-server /usr/local/bin/
 if [ -f ${CONF} ]; then
   echo "Found existing config..."
   else
   if [ -z ${PSK} ]; then
     PSK=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
     echo "Using generated PSK: ${PSK}"
   else
     echo "Using predefined PSK: ${PSK}"
   fi
   mkdir /etc/snell/
   echo "Generating new config..."
   echo "[snell-server]" >>${CONF}
   echo "listen = 0.0.0.0:13254" >>${CONF}
   echo "psk = ${PSK}" >>${CONF}
   echo "obfs = tls" >>${CONF}
 fi
 if [ -f ${SYSTEMD} ]; then
   echo "Found existing service..."
   systemctl daemon-reload
   systemctl restart snell
 else
   echo "Generating new service..."
   echo "[Unit]" >>${SYSTEMD}
   echo "Description=Snell Proxy Service" >>${SYSTEMD}
   echo "After=network.target" >>${SYSTEMD}
   echo "" >>${SYSTEMD}
   echo "[Service]" >>${SYSTEMD}
   echo "Type=simple" >>${SYSTEMD}
   echo "LimitNOFILE=32768" >>${SYSTEMD}
   echo "ExecStart=/usr/local/bin/snell-server -c /etc/snell/snell-server.conf" >>${SYSTEMD}
   echo "" >>${SYSTEMD}
   echo "[Install]" >>${SYSTEMD}
   echo "WantedBy=multi-user.target" >>${SYSTEMD}
   systemctl daemon-reload
   systemctl enable snell
   systemctl start snell
 fi
 