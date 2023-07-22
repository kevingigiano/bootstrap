#!/bin/bash
# Kevin Gigiano
# 07-22-2023
#
# This script will bootstrap my local developemnt environment.
# RHEL8+ or CentOS8+ 

function usage() {
  echo ""
  echo "usage: $0"
  echo "    -a (OPTIONAL) automode; supply n,N,y,Y"
  echo "    -h Show this message"
  echo ""
  exit 1
}

while getopts a:h option; do
  case "${option}" in
    a) AUTO="${OPTARG}";;
    h) usage;;
    *) usage
      exit 1;;
  esac
done

START_DIR=`pwd`
INSTALL_DIR="$HOME/install"
DEV_DIR="$HOME/git"

# Create dev directory
if [ ! -d $DEV_DIR ] ;then
    mkdir $DEV_DIR
fi

# Add user to sudoers
sudo sed -i "s/# %wheel/%wheel/g" /etc/sudoers

# Set hostname
sudo hostnamectl set-hostname cent9-devbox

# get subnet
subnet=`ip a | grep "inet " | tail -1 | awk '{print $2}'`

# get router/gateway
router=`ip route show | head -1 | awk '{print $3}'`

# get size of network portion of address in bytes
sz=`echo $subnet | awk -F / '{print $2}'`
bytes=`expr $sz / 8`
prefix=`echo $subnet | cut -d. -f1-$bytes`      # e.g., 192.168.0

# get IP address to be set
IP=`hostname -I | awk '{print $1}'`             # current IP

# fetch the UUID
UUID=`nmcli connection show | head -2 | tail -1 | awk '{print $4}'`

echo "size:$sz"
echo "bytes:$bytes"
echo "prefix:$prefix"
echo "ip:$IP"
echo "subnet:$subnet"
echo "gateway:$router"
echo "dns:$router"
echo "UUID:$UUID"

printf 'IP settings look good (y/n)? '
if [ "$AUTO" = "Y" ] || [ "$AUTO" = "y" ] || [ "$AUTO" = "N" ] || [ "$AUTO" = "n" ] ;then
    answer=$AUTO
else
    read answer
fi

if [ "$answer" = "N" ] || [ "$answer" = "n" ]  ;then 
    echo "bye!"
    exit 1
fi

# run commands to set up the permanent IP address
sudo nmcli connection modify $UUID IPv4.address $IP/$sz
sudo nmcli connection modify $UUID IPv4.gateway $router
sudo nmcli connection modify $UUID IPv4.method manual
sudo nmcli connection modify $UUID ipv4.dns $router
sudo nmcli connection up $UUID

# Check for upgrades & updates
sudo dnf upgrade -y && sudo dnf update -y

# Create install directory
if [ ! -d $INSTALL_DIR ] ;then
    mkdir $INSTALL_DIR
fi

# Install Docker
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf list docker-ce
sudo dnf install docker-ce --nobest -y
sudo systemctl enable docker
sudo systemctl start docker
sudo groupadd docker
sudo usermod -a -G docker $USER

# Install docker autocomplete
sudo curl https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker -o /etc/bash_completion.d/docker.sh

# Install yq
BINARY=yq_linux_amd64 
LATEST=$(wget -qO- https://api.github.com/repos/mikefarah/yq/releases/latest 2>/dev/null | grep browser_download_url | grep $BINARY\"\$|awk '{print $NF}' )
sudo wget -q $LATEST -O /usr/bin/yq && sudo chmod +x /usr/bin/yq

# Install Git
sudo dnf install git -y

# Install Python3 Network Tools
sudo dnf install python3-ethtool -y

# Install VSCode
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
dnf check-update
sudo dnf install code -y

# Install Google Chrome
sudo bash -c 'cat > /etc/yum.repos.d/google-chrome.repo <<EOF
dgoogle-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF'
sudo dnf install google-chrome-stable -y

printf 'Do you want to install k8s apps (y/n)? '
if [ "$AUTO" = "Y" ] || [ "$AUTO" = "y" ] || [ "$AUTO" = "N" ] || [ "$AUTO" = "n" ] ;then
    answer=$AUTO
else
    read answer
fi


if [ "$answer" = "Y" ] || [ "$answer" = "y" ]  ;then
    echo "Installing k8s apps"
    
    # Install Helm
    cd $INSTALL_DIR
    if [ ! -d helm ] ;then
        mkdir helm
    fi
    cd helm
    wget https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz
    tar xzvf helm-v3.12.0-linux-amd64.tar.gz
    sudo cp linux-amd64/helm /usr/local/bin
    
    # Install Kubectl
    cd $INSTALL_DIR
    if [ ! -d kubectl ] ;then
        mkdir kubectl
    fi
    cd kubectl
    wget https://dl.k8s.io/v1.27.0/kubernetes-client-linux-amd64.tar.gz
    tar xzvf kubernetes-client-linux-amd64.tar.gz
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    sudo install -o root -g root -m 0755 kubernetes/client/bin/kubectl /usr/local/bin/kubectl
    
    # Install Minikube
    cd $INSTALL_DIR
    if [ ! -d minikube ] ;then
        mkdir minikube
    fi
    cd minikube
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    
    # Install ArgoCD CLI
    cd $INSTALL_DIR
    if [ ! -d argocd ] ;then
        mkdir argocd
    fi
    cd argocd
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
    
else
    echo "Skipping k8s installs"
fi

# Copy and source bashrc
cp $START_DIR/bashrc ~/.bashrc
source ~/.bashrc

printf 'Docker will not work right until your reboot.  Reboot (y/n)? '
read answer

if [ "$answer" = "Y" ] || [ "$answer" = "y" ]  ;then
    echo "Rebooting"
    sudo init 6
fi

