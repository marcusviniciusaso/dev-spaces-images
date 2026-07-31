#!/bin/sh
#
# Copyright (c) 2019-2024 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#

set -e

export USER_ID=$(id -u)
export GROUP_ID=$(id -g)

jdk_import_ca_bundle() {
  CA_BUNDLE="${JDK_CA_BUNDLE:-/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem}"
  KEYSTORE_PASSWORD="${JDK_KEYSTORE_PASSWORD:-changeit}"

  if ! command -v keytool >/dev/null 2>&1; then
    return
  fi

  if [ ! -f "$CA_BUNDLE" ]; then
    echo "[jdk] Failed to import CA certificates from ${CA_BUNDLE}. File doesn't exist"
    return
  fi

  bundle_name=$(basename "$CA_BUNDLE")
  certs_imported=0
  cert_index=0
  tmp_file=/tmp/cert.pem
  is_cert=false
  echo "[jdk] Importing certificates..."
  while IFS= read -r line; do
    if [ "$line" = "-----BEGIN CERTIFICATE-----" ]; then
      is_cert=true
      cert_index=$((cert_index+1))
      echo "$line" > ${tmp_file}
    elif [ "$line" = "-----END CERTIFICATE-----" ]; then
      is_cert=false
      echo "$line" >> ${tmp_file}
      if keytool -import -trustcacerts -cacerts -storepass "$KEYSTORE_PASSWORD" -noprompt -alias "${bundle_name}_${cert_index}" -file $tmp_file; then
        certs_imported=$((certs_imported+1))
      fi
      certs_imported=$((certs_imported+1))
    elif [ "$is_cert" = true ]; then
      echo "$line" >> ${tmp_file}
    fi
  done < "$CA_BUNDLE"

  echo "[jdk] Imported ${certs_imported} certificates from ${CA_BUNDLE}"
  rm -f $tmp_file
}

if ! grep -Fq "${USER_ID}" /etc/passwd; then
    # current user is an arbitrary
    # user (its uid is not in the
    # container /etc/passwd). Let's fix that
    cat ${HOME}/passwd.template | \
    sed "s/\${USER_ID}/${USER_ID}/g" | \
    sed "s/\${GROUP_ID}/${GROUP_ID}/g" | \
    sed "s/\${HOME}/\/home\/user/g" > /etc/passwd

    cat ${HOME}/group.template | \
    sed "s/\${USER_ID}/${USER_ID}/g" | \
    sed "s/\${GROUP_ID}/${GROUP_ID}/g" | \
    sed "s/\${HOME}/\/home\/user/g" > /etc/group
fi

# The user namespace is created when `UserNamespacesSupport` feature is enabled and `hostUsers` is set to false in Pod spec.
# See for more details:
# - https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/#introduction
# Assume, that HOST_USERS environment variable is provided and is set to false in that case.
# If so, update /etc/sub*id files to reflect the valid UID/GID range.
if [ "${HOST_USERS}" == "false" ]; then
  echo "Running in a user namespace"
  if [ -f /proc/self/uid_map ]; then
    # Typical output of `/proc/self/uid_map`:
    # 1. When NOT running in a user namespace:
    #         0          0 4294967295
    # 2. When running in a user namespace:
    #         0 1481179136      65536
    # 3. When container is run in a user namespace:
    #         0       1000          1
    #         1       1001      64535
    # We can use the content of /proc/self/uid_map to detect if we are running in a user namespace.
    # However, to keep things simple, we will rely on HOST_USERS environment variable only.
    # This way, we avoid breaking anything.
    echo "/proc/self/uid_map content: $(cat /proc/self/uid_map)"
  fi

  # Why do we need to update /etc/sub*id files?
  # We are already in the user namespace, so we know there are at least 65536 UIDs/GIDs available.
  # For more details, see:
  # - https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/#id-count-for-each-of-pods
  # Podman needs to create a new user namespace for any container being launched and map the container's user
  # and group IDs (UID/GID) to the corresponding user on the current namespace.
  # For the mapping, podman refers to the /etc/sub*id files.
  # For more details, see:
  # - https://man7.org/linux/man-pages/man5/subuid.5.html
  # So if the user ID exceeds 65535, it cannot be mapped if only UIDs/GIDs from 0-65535 are available.
  # If that's the case, podman commands would fail.

  # Even though the range can be extended using configuration, we can rely on the fact that there are at least 65536 user IDs available in the user namespace.
  # See for more details:
  # - https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-UserNamespaces

  # To ensure the provided user ID stays within this range, `runAsUser` in the Pod spec should be set to a value below 65536.
  # In OpenShift, the Container Security Context Constraint (SCC) should be created accordingly.
  if whoami &> /dev/null; then
    echo "User information: $(id)"

    USER_ID=$(id -u)
    if [ ${USER_ID} -lt 65536 ]; then
      USER_NAME=$(whoami)
      START_ID=$(( ${USER_ID} + 1 ))
      COUNT=$(( 65536 - ${START_ID} ))
      IDS_RANGE="${USER_NAME}:${START_ID}:${COUNT}"

      if [ -w /etc/subuid ]; then
        echo "${IDS_RANGE}" > /etc/subuid
        echo "/etc/subuid updated"
      fi
      if [ -w /etc/subgid ]; then
        echo "${IDS_RANGE}" > /etc/subgid
        echo "/etc/subgid updated"
      fi
    fi
  fi
fi


#############################################################################
# Grant access to projects volume in case of non root user with sudo rights
#############################################################################
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && sudo -n true > /dev/null 2>&1; then
    sudo chown "${USER_ID}:${GROUP_ID}" /projects
fi

if [ -f "${HOME}"/.venv/bin/activate ]; then
  source "${HOME}"/.venv/bin/activate
fi

#############################################################################
# use java 8 if USE_JAVA8 is set to 'true', 
# use java 11 if USE_JAVA11 is set to 'true',
# use java 21 if USE_JAVA21 is set to 'true', 
# by default it is java 17
#############################################################################
rm -rf /home/tooling/.java/current
mkdir -p /home/tooling/.java/current
if [ "${USE_JAVA17}" == "true" ] && [ ! -z "${JAVA_HOME_17}" ]; then
  ln -s "${JAVA_HOME_17}"/* /home/tooling/.java/current
  echo "Java environment set to ${JAVA_HOME_17}"
elif [ "${USE_JAVA11}" == "true" ] && [ ! -z "${JAVA_HOME_11}" ]; then
  ln -s "${JAVA_HOME_11}"/* /home/tooling/.java/current
  echo "Java environment set to ${JAVA_HOME_11}"
elif [ "${USE_JAVA21}" == "true" ] && [ ! -z "${JAVA_HOME_21}" ]; then
  ln -s "${JAVA_HOME_21}"/* /home/tooling/.java/current
  echo "Java environment set to ${JAVA_HOME_21}"
else
  if [ ! -z "${JAVA_HOME_25}" ]; then
    ln -s "${JAVA_HOME_25}"/* /home/tooling/.java/current
    echo "Java environment set to ${JAVA_HOME_25}"
  elif [ ! -z "${JAVA_HOME_21}" ]; then
    ln -s "${JAVA_HOME_21}"/* /home/tooling/.java/current
    echo "Java environment set to ${JAVA_HOME_21} (fallback)"
  elif [ ! -z "${JAVA_HOME_17}" ]; then
    ln -s "${JAVA_HOME_17}"/* /home/tooling/.java/current
    echo "Java environment set to ${JAVA_HOME_17} (fallback)"
  else
    echo "WARNING: No JAVA_HOME found, skipping Java symlink setup"
  fi
fi

if [[ ! -z "${PLUGIN_REMOTE_ENDPOINT_EXECUTABLE}" ]]; then
  ${PLUGIN_REMOTE_ENDPOINT_EXECUTABLE}
fi

#############################################################################
# If KUBEDOCK_ENABLED="true" then link podman to /usr/bin/podman-wrapper.sh
# else link podman to /usr/bin/podman.orig
#############################################################################
if [[ "${KUBEDOCK_ENABLED:-false}" == "true" ]]; then
    echo
    echo "Kubedock is enabled (env variable KUBEDOCK_ENABLED is set to true)."

    SECONDS=0
    KUBEDOCK_TIMEOUT=${KUBEDOCK_TIMEOUT:-10}
    until [ -f $KUBECONFIG ]; do
        if (( SECONDS > KUBEDOCK_TIMEOUT )); then
            break
        fi
        echo "Kubeconfig doesn't exist yet. Waiting..."
        sleep 1
    done

    if [ -f $KUBECONFIG ]; then
      echo "Kubeconfig found."

      KUBEDOCK_PARAMS=${KUBEDOCK_PARAMS:-"--reverse-proxy --kubeconfig $KUBECONFIG"}

      echo "Starting kubedock with params \"${KUBEDOCK_PARAMS}\"..."

      kubedock server ${KUBEDOCK_PARAMS} > /tmp/kubedock.log 2>&1 &

      echo "Done."

      echo "Replacing podman with podman-wrapper.sh..."

      ln -f -s /usr/bin/podman-wrapper.sh /home/tooling/.local/bin/podman

      export TESTCONTAINERS_RYUK_DISABLED="true"
      export TESTCONTAINERS_CHECKS_DISABLE="true"

      echo "Done."
      echo
    else
        echo "Could not find Kubeconfig at $KUBECONFIG"
        echo "Giving up..."
    fi
else
    echo
    echo "Kubedock is disabled. It can be enabled with the env variable \"KUBEDOCK_ENABLED=true\""
    echo "set in the workspace Devfile or in a Kubernetes ConfigMap in the developer namespace."
    echo
    ln -f -s /usr/bin/podman.orig /home/tooling/.local/bin/podman
fi

# Configure container builds to use vfs or fuse-overlayfs
if [ ! -d "${HOME}/.config/containers" ]; then
  mkdir -p ${HOME}/.config/containers
  if [ -c "/dev/fuse" ] && [ -f "/usr/bin/fuse-overlayfs" ]; then
    (echo '[storage]';echo 'driver = "overlay"';echo '[storage.options.overlay]';echo 'mount_program = "/usr/bin/fuse-overlayfs"') > ${HOME}/.config/containers/storage.conf
  else
    (echo '[storage]';echo 'driver = "vfs"') > "${HOME}"/.config/containers/storage.conf
  fi
fi

#############################################################################
# Stow: If persistUserHome is enabled, then the contents of /home/user/
# will be mounted by a PVC and overwritten. In this case, we use stow to
# create symbolic links from /home/tooling/ -> /home/user/.
# Required for https://github.com/eclipse/che/issues/22412
#############################################################################

# /home/user/ will be mounted to by a PVC if persistUserHome is enabled
# We need to override the `set -e` from this script by ensuring the mountpoint command returns 0,
# but we also need to capture the exit code of mountpoint
HOME_USER_MOUNTED=0
mountpoint -q /home/user/ || HOME_USER_MOUNTED=$?

# This file will be created after stowing, to guard from executing stow everytime the container is started
STOW_COMPLETE=/home/user/.stow_completed

if [ $HOME_USER_MOUNTED -eq 0 ] && [ ! -f $STOW_COMPLETE ]; then
    # There may be regular, non-symlink files in /home/user that match the
    # pathing of files in /home/tooling. Stow will error out when it tries to
    # stow on top of that. Instead, we can append to the current
    # /home/tooling/.stow-local-ignore file to ignore pre-existing,
    # non-symlinked files in /home/user that match those in /home/tooling before
    # we run stow.
    #
    # Create two text files containing a sorted path-based list of files in
    # /home/tooling and /home/user. Cut off "/home/user" and "/home/tooling" and
    # only get the sub-paths so we can do a proper comparison
    #
    # In the case of /home/user, we want regular file types and not symbolic
    # links.
    find /home/user -type f -xtype f -print  | sort | sed 's|/home/user||g' > /tmp/user.txt
    find /home/tooling -print | sort | sed 's|/home/tooling||g' > /tmp/tooling.txt
    # We compare the two files, trying to find files that exist in /home/user
    # and /home/tooling. Being that the files that get flagged here are not
    # already synlinks, we will want to ignore them.
    IGNORE_FILES="$(comm -12 /tmp/user.txt /tmp/tooling.txt)"
    # We no longer require the file lists, so remove them
    rm /tmp/user.txt /tmp/tooling.txt
    # For each file we need to ignore, append them to
    # /home/tooling/.stow-local-ignore.
    for f in $IGNORE_FILES; do echo "${f}" >> /home/tooling/.stow-local-ignore;done
    # We are now ready to run stow
    #
    # Create symbolic links from /home/tooling/ -> /home/user/
    stow . -t /home/user/ -d /home/tooling/ --no-folding -v 2 > /tmp/stow.log 2>&1

    touch $STOW_COMPLETE
fi

# Read .copy-files and copy files from /home/tooling to /home/user
if [ -f "/home/tooling/.copy-files" ]; then
    echo "Processing .copy-files..."
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty and commented lines
        [[ -z "$line" || "$line" == \#* ]] && continue

        if [ -e "/home/tooling/$line" ]; then
            tooling_path=$(realpath "/home/tooling/$line")
            
            # Determine target path based on whether source is a directory
            if [ -d "$tooling_path" ]; then
                # For directories: copy to parent directory (e.g., dir1/dir2 -> /home/user/dir1/)
                target_parent=$(dirname "/home/user/$line")
                target_full="$target_parent/$(basename "$tooling_path")"
                
                # Skip if target directory already exists
                if [ -d "$target_full" ]; then
                    echo "Directory $target_full already exists, skipping..."
                    continue
                fi
                
                echo "Copying directory $tooling_path to $target_parent/"
                mkdir -p "$target_parent"
                cp --no-clobber -r "$tooling_path" "$target_parent/"
            else
                # For files: copy to exact target path
                target_full="/home/user/$line"
                target_parent=$(dirname "$target_full")

                # Skip if target file already exists
                if [ -e "$target_full" ]; then
                    echo "File $target_full already exists, skipping..."
                    continue
                fi
                
                echo "Copying file $tooling_path to $target_full"
                mkdir -p "$target_parent"
                cp --no-clobber -r "$tooling_path" "$target_full"
            fi
        else
            echo "Warning: /home/tooling/$line does not exist, skipping..."
        fi
    done < /home/tooling/.copy-files
    echo "Finished processing .copy-files."
else
    echo "No .copy-files found, skipping copy operation."
fi

# Create symlinks from /home/tooling/.config to /home/user/.config
# Only create symlinks for files that don't already exist in destination.
# This is done because stow ignores the .config directory.
if [ -d /home/tooling/.config ]; then
    echo "Creating .config symlinks for files that don't already exist..."
    
    # Find all files recursively in /home/tooling/.config
    find /home/tooling/.config -type f | while read -r file; do
        # Get the relative path from /home/tooling/.config
        relative_path="${file#/home/tooling/.config/}"
        
        # Determine target path in /home/user/.config
        target_file="${HOME}/.config/${relative_path}"
        target_dir=$(dirname "$target_file")
        
        # Only create symlink if target file doesn't exist
        if [ ! -e "$target_file" ]; then
            # Create target directory if it doesn't exist
            mkdir -p "$target_dir"
            # Create symbolic link
            ln -s "$file" "$target_file"
            echo "Created symlink: $target_file -> $file"
        else
            echo "File $target_file already exists, skipping..."
        fi
    done
    
    echo "Finished creating .config symlinks."
fi

jdk_import_ca_bundle &

exec "$@"