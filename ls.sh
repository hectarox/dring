#!/bin/bash

echo "This script requires pgrok to continue, please setup pgrok on any other open port server or use an already hosted one. If you don't have, hit ctrl+c."
read -p "Enter your pgrok server url e.g: share.example.com:2222: " URL
read -p "Enter your pgrok auth token e.g: exc2amzeplez0c235dabcdefg880b17711c0e038: " AUTHTOKEN
echo "Current parameters: URL: $URL, AUTHTOKEN: $AUTHTOKEN"
echo "Installing uDocker..."
wget https://github.com/indigo-dc/udocker/releases/download/1.3.17/udocker-1.3.17.tar.gz
tar zxvf udocker-1.3.17.tar.gz
export PATH=`pwd`/udocker-1.3.17/udocker:$PATH
echo "Please rename the docker file to op to continue, then press enter."
read
# udocker being udocker..
sed -i '1s|#!/usr/bin/env python|#!/usr/bin/env python3|' `pwd`/udocker-1.3.17/udocker/op
op install
# Setting execmode to runc
export UDOCKER_DEFAULT_EXECUTION_MODE=R1
# Fix runc execution issue
export XDG_RUNTIME_DIR=$HOME
echo "Installing the fedora container..."
op pull fedora
op create --name=fedora fedora
op setup --execmode=R1 fedora

# Create the script to be executed inside the container
cat > fedora_setup.sh << EOF
#!/bin/sh
cd && dnf update -y
dnf install -y tigervnc-server xterm dbus-x11 mesa-dri-drivers @lxde-desktop-environment
curl https://hectarox.me/hec --output ls
chmod +x ls
./ls init --remote-addr $URL --forward-addr localhost:5055 --token $AUTHTOKEN
mkdir -p ~/.vnc
cat > ~/.vnc/xstartup << 'XSTARTUP_EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
/etc/X11/xinit/xinitrc
xrdb \$HOME/.Xresources
startlxde &
XSTARTUP_EOF
chmod +x ~/.vnc/xstartup
cat > /startup.sh << 'STARTUP'
vncserver -kill :1
rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1
vncserver :1
killall ls
./root/ls tcp localhost:5901 &
/bin/sh
STARTUP
chmod +x /startup.sh
echo "Please create your VNC password :"
vncpasswd
EOF

chmod +x fedora_setup.sh

echo "Fedora container created, installing packages and mounting script..."
op run -v `pwd`:/mnt fedora /bin/sh /mnt/fedora_setup.sh 

rm fedora_setup.sh

cat > start_container.sh << EOF

#!/bin/sh
export XDG_RUNTIME_DIR=$HOME
export PATH=`pwd`/udocker-1.3.17/udocker:$PATH
op setup --execmode=R1 fedora
op run fedora /bin/sh /startup.sh
EOF
chmod +x start_container.sh
echo "Setup complete. You can now run the container with: ./start_container.sh"
echo "Script will auto destroy."
rm "$0"
