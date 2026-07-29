# podman login
nexus-login() { echo "podman login <NEXUSREPOSITORY>:<PORT>"; }

# podman pull base-images
nexus-pull-base() {
    echo "podman image pull <NEXUSREPOSITORY>:<PORT>/images/image:<TAG>";
}

# podman pull external-images
nexus-pull-external() {
    echo "podman image pull <NEXUSREPOSITORY>:<PORT>/external-images/image:<TAG>";
}

# podman pull custom-images
nexus-pull-custom() {
    echo "podman image pull <NEXUSREPOSITORY>:<PORT>/custom-images/image:<TAG>";
}

# podman push base-images
nexus-push-base() {
    echo "podman image push <NEXUSREPOSITORY>:<PORT>/images/image:<TAG>";
}

# podman push external-images
nexus-push-external() {
    echo "podman image push <NEXUSREPOSITORY>:<PORT>/external-images/image:<TAG>";
}

# podman push custom-images
nexus-push-custom() {
    echo "podman image push <NEXUSREPOSITORY>:<PORT>/custom-images/image:<TAG>";
}

devspaces-linux-release(){
    cat /etc/devspaces-linux-release
}

devspaces-environment() {
    bash ~/devspaces-environment.sh
}

devspaces-setup() {
    bash ~/devspaces-setup.sh
}

# Show current git branch with colors in Bash prompt
parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}