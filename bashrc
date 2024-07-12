# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi

# EXPORTS
export PATH
export KUBECONFIG=~/atlas-k8s-config
export DOCKER_HOST=tcp://localhost:2375
export JAVA_HOME=/etc/alternatives/jre_17
export DB_CERT_PATH=~/ATLAS/db-certs
export KAFKA_CERT_PATH=~/ATLAS/broker-certs

# ALIASES

# Git Alias
# view log
alias gl="git log"
# diff file changes with master
alias gd="git diff $1 master"
# get current branch status
alias gs="git status"
# pull any remote changes to current branch
alias gp="git pull"
# push any committed changes to remote
alias gpp="git push"
# check branch you are on
alias gb="git branch"
# check all branches
alias gbr="git branch -r"
# checkout new local branch
alias gcb="git checkout -b $1"
# switch to existing branch
alias gsb="git checkout $1"
# stage new 'or changed files
alias ga="git add *"
# commit staged files with message
alias gc="git commit -m $1"
# print remote repo
alias gr="git remote -v"
# clone repo
alias gcl="git clone $1"
# delete local branch
alias gbd="git branch -d $1"

# Docker Alias
alias dri='function _dri(){ docker run -it --rm $1 bash; };_dri'
alias drig='function _drig(){ docker run -it --rm -p 5900:5900 $1 bash; };_drig'
alias di="docker images"
alias ddi="docker rmi "
alias dpi="docker pull "
alias dps="docker ps"
alias dei='function _dei(){ docker exec -it $1 bash; };_dei'
alias ddc='function _ddc(){ docker container rm $1 -f; };_ddc'
alias dc="docker container ls -a"

# kubctl 
alias k=kubectl
alias kl="kubectl logs -n $1"
alias kgp="kubectl get pods -n $1"
alias kdp="kubectl describe pods -n $1"
alias kgc="kubectl config get-contexts"
alias kuc="kubectl config use-context $1"

# Other Alias
alias watch="watch -n .5 "
alias mci="mvn clean install"
alias tv="trivy image $1"
# check certs
alias ccert="openssl x509 -text -noout -in $1"
# File grep
alias frep="find | grep $1"
alias cls=clear
alias ll="ls -la"
# Cluster login
alias aks-login='~/aks-login.sh'

# all reverse search
stty -ixon

# SOURCE
# source bash completions
source <(kubectl completion bash | sed s/kubectl/k/g)
source <(helm completion bash)
source <(minikube completion bash)
source <(argocd completion bash)
# handy file for pulling in credentials
source ~/.creds


