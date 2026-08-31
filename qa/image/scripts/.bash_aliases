# podman login (persistent credentials via REGISTRY_AUTH_FILE)
podman-login() { /usr/local/bin/podman-login; }
jfrog-login() { podman-login; }

# podman pull
jfrog-pull() {
    echo "podman image pull <REGISTRY>/<REPO>/<IMAGE>:<TAG>;"
}

# podman push
jfrog-push() {
    echo "podman image push <REGISTRY>/<REPO>/<IMAGE>:<TAG>;"
}

devspaces-linux-release(){
    cat /etc/devspaces-linux-release
}

devspaces-environment() {
    bash /home/tooling/devspaces-environment.sh
}

devspaces-setup() {
    bash /home/tooling/devspaces-setup.sh
}

# Colored prompt with workspace name, directory, and git branch (inline git command)
export PS1="\[\e[34m\]${DEVWORKSPACE_NAME:-\u@\h} \[\e[32m\]\w \[\e[91m\]\$(git branch 2>/dev/null | sed -n 's/* \(.*\)/(\1)/p')\[\e[00m\]\$ "