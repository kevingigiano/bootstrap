#!/bin/bash
# Kevin Gigiano
# 07-22-2023
#
# This script will bootstrap my local developemnt environment.
# RHEL9+ or CentOS9+ 

COLOR_NC='\033[0m' # No Color
COLOR_BLACK='\033[0;30m'
COLOR_GRAY='\033[1;30m'
COLOR_RED='\033[0;31m'
COLOR_LIGHT_RED='\033[1;31m'
COLOR_GREEN='\033[0;32m'
COLOR_LIGHT_GREEN='\033[1;32m'
COLOR_BROWN='\033[0;33m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_LIGHT_BLUE='\033[1;34m'
COLOR_PURPLE='\033[0;35m'
COLOR_LIGHT_PURPLE='\033[1;35m'
COLOR_CYAN='\033[0;36m'
COLOR_LIGHT_CYAN='\033[1;36m'
COLOR_LIGHT_GRAY='\033[0;37m'
COLOR_WHITE='\033[1;37m'

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
  esac
done

START_DIR=$(pwd)
INSTALL_DIR="$HOME/install"
DEV_DIR="$HOME/git"

# Create dev directory
if [ ! -d "$DEV_DIR" ] ;then
    mkdir "$DEV_DIR"
fi


CERT_DIR="$INSTALL_DIR/certs"
if [ ! -d "$CERT_DIR" ] ;then
    mkdir "$CERT_DIR"
fi

echo -e "Some networks man-in-the-middled you and requires special certificates installed.\n
Place any special certificates in the following directory:${COLOR_YELLOW} $CERT_DIR ${COLOR_NC}now so installs don't fail due to certificate errors"
echo "Done with special certificates?"
read -r answer

# Install any custom certificates
printf 'Install custom certificates (y/n)? '
if [ "$AUTO" = "Y" ] || [ "$AUTO" = "y" ] || [ "$AUTO" = "N" ] || [ "$AUTO" = "n" ] ;then
    answer=$AUTO
else
    read -r answer
fi
if [ "$answer" = "Y" ] || [ "$answer" = "y" ]  ;then
    printf "Place your certs in %s/certs and press return, $INSTALL_DIR"
    if [ "$AUTO" = "Y" ] || [ "$AUTO" = "y" ] || [ "$AUTO" = "N" ] || [ "$AUTO" = "n" ] ;then
    answer=$AUTO
    else
        read -r answer
    fi
    sudo cp "$CERT_DIR"/* /etc/pki/ca-trust/source/anchors/
    sudo update-ca-trust extract
fi

# Add user to sudoers
sudo sed -i "s/# %wheel/%wheel/g" /etc/sudoers

# Set hostname
sudo hostnamectl set-hostname cent9-devbox

# Get subnet
subnet=$(ip a | grep "inet " | tail -1 | awk '{print $2}')

# Get router/gateway
router=$(ip route show | head -1 | awk '{print $3}')

# Get size of network portion of address in bytes
sz=$(echo "$subnet" | awk -F / '{print $2}')
bytes=$(("$sz" / 8))
prefix=$(echo "$subnet" | cut -d. -f1-"$bytes")      # e.g., 192.168.0

# Get IP address to be set
IP=$(hostname -I | awk '{print $1}')             # current IP

# Fetch the UUID
UUID=$(nmcli connection show | head -2 | tail -1 | awk '{print $4}')

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
    read -r answer
fi

if [ "$answer" = "N" ] || [ "$answer" = "n" ]  ;then 
    echo "bye!"
    exit 1
fi

# Run commands to set up the permanent IP address
sudo nmcli connection modify "$UUID" IPv4.address "$IP"/"$sz"
sudo nmcli connection modify "$UUID" IPv4.gateway "$router"
sudo nmcli connection modify "$UUID" IPv4.method manual
sudo nmcli connection modify "$UUID" ipv4.dns "$router"
sudo nmcli connection up "$UUID"

# Check for upgrades & updates
sudo dnf upgrade -y && sudo dnf update -y

# Create install directory
if [ ! -d "$INSTALL_DIR" ] ;then
    mkdir "$INSTALL_DIR"
fi

# JAVA 17
echo "Installing Docker"
sudo dnf install java-17-openjdk java-17-openjdk-devel -y


# Install Docker
echo "Installing Docker"
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf list docker-ce
sudo dnf install docker-ce --nobest -y
sudo systemctl enable docker
sudo systemctl start docker
sudo groupadd docker
sudo usermod -a -G docker "$USER"

# Add Docker daemon file for Maven buils
sudo sh -c 'echo -e "{\n  \"hosts\": [\n    \"tcp://0.0.0.0:2375\",\n    \"unix:///var/run/docker.sock\"\n  ]\n}" > /etc/docker/daemon.json'

# Open port for Docker endpoint
echo "Fixing Docker endpoint"
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo sh -c 'echo -e "[Service]\nExecStart=\nExecStart=/usr/bin/dockerd" > /etc/systemd/system/docker.service.d/options.conf'
sudo systemctl daemon-reload
sudo systemctl restart docker

# Install docker autocomplete
echo "Installing Docker autocomplete"
sudo curl https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker -o /etc/bash_completion.d/docker.sh

# Install yq
echo "Installing YQ"
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq

# Install Git
echo "Installing Git"
sudo dnf install git -y

# Install Python3 Network Tools
sudo dnf install python3-ethtool -y

# Install VSCode
echo "Installing VS Code"
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
dnf check-update
sudo dnf install code -y

# Install Google Chrome
echo "Installing Chrome"
sudo sh -c 'echo -e "[google-chrome]\nname=google-chrome\nbaseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64\nenabled=1\ngpgcheck=1\ngpgkey=https://dl.google.com/linux/linux_signing_key.pub" > /etc/yum.repos.d/google-chrome.repo'
sudo dnf install google-chrome-stable -y

# Fix GNOME
printf 'Do you want to fix GNOME (y/n)? '
if [ "$AUTO" = "Y" ] || [ "$AUTO" = "y" ] || [ "$AUTO" = "N" ] || [ "$AUTO" = "n" ] ;then
    answer=$AUTO
else
    read -r answer
fi
if [ "$answer" = "Y" ] || [ "$answer" = "y" ]  ;then
    # Remove GDM
    echo "Installing KDE"
    sudo dnf install epel-release -y
    sudo dnf config-manager --set-enabled crb
    sudo dnf -y groupinstall "KDE Plasma Workspaces" "base-x"

    echo "Removing portal"
    sudo dnf remove xdg-desktop-portal-kde -y
fi

printf 'Do you want to install k8s apps (y/n)? '
if [ "$AUTO" = "Y" ] || [ "$AUTO" = "y" ] || [ "$AUTO" = "N" ] || [ "$AUTO" = "n" ] ;then
    answer=$AUTO
else
    read -r answer
fi
if [ "$answer" = "Y" ] || [ "$answer" = "y" ]  ;then

    echo "Installing k8s apps"

    # Install Helm
    echo "Installing helm"
    cd "$INSTALL_DIR" || exit
    if [ ! -d helm ] ;then
        mkdir helm
    fi
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod +x get_helm.sh
    sudo ./get_helm.sh

    # Install Kubectl
    echo "Installing kubectl"
    sudo sh -c 'echo -e "[kubernetes]\nname=Kubernetes\nbaseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/\nenabled=1\ngpgcheck=1\ngpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key" > /etc/yum.repos.d/kubernetes.repo'
    sudo dnf install -y kubectl

    # Install Minikube
    echo "Installing minikube"
    cd "$INSTALL_DIR" || exit
    if [ ! -d minikube ] ;then
        mkdir minikube
    fi
    cd minikube || exit
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    
    # Install ArgoCD CLI"
    echo "Installing ArgoCD CLI"
    cd "$INSTALL_DIR" || exit
    if [ ! -d argocd ] ;then
        mkdir argocd
    fi
    cd argocd || exit
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
    
else
    echo "Skipping k8s installs"
fi

# Install Python packeges
echo "Installing Python Stuff"
sudo dnf install pip -y
pip install cookiecutter

# Install Maven
echo "Installing Maven "
sudo dnf install maven -y

# Install Azure CLI
echo "Installing Azure CLI"
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo dnf install -y https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm
sudo dnf install azure-cli -y
sudo az aks install-cli -y

# Copy and source bashrc
printf 'Update and overwrite bashrc (y/n)? '
if [ "$AUTO" = "Y" ] || [ "$AUTO" = "y" ] || [ "$AUTO" = "N" ] || [ "$AUTO" = "n" ] ;then
    answer=$AUTO
else
    read -r answer
fi
if [ "$answer" = "Y" ] || [ "$answer" = "y" ]  ;then
    cp "$START_DIR"/bashrc ~/.bashrc
    source ~/.bashrc
fi

# Update /etc/resolv.conf
printf 'Add nameserver to /etc/resolve.conf and make readonly (y/n)? '
if [ "$AUTO" = "Y" ] || [ "$AUTO" = "y" ] || [ "$AUTO" = "N" ] || [ "$AUTO" = "n" ] ;then
    answer=$AUTO
else
    read -r answer
fi
if [ "$answer" = "Y" ] || [ "$answer" = "y" ]  ;then
    printf 'Enter nameserver and hit enter '
    if [ "$AUTO" = "Y" ] || [ "$AUTO" = "y" ] || [ "$AUTO" = "N" ] || [ "$AUTO" = "n" ] ;then
        answer=172.16.2.20
    else
        read -r answer
    fi
    echo "nameserver $answer" | cat - /etc/resolv.conf > temp && sudo mv temp /etc/resolv.conf
    sudo chattr +i -f /etc/resolv.conf
fi

printf 'Docker will not work right until your reboot.  Reboot (y/n)? '
read -r answer

if [ "$answer" = "Y" ] || [ "$answer" = "y" ]  ;then
    echo "Rebooting"
    sudo init 6
fi

