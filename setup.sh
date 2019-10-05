#!/bin/bash

VERSION=0.4.0
DOCKER_COMPOSE_VERSION=1.24.1

function is_root {
    if [ "$EUID" -ne 0 ]; then
        echo "Sorry, you need to run this script as root."
        exit 1
    fi
}

function check_os {
    case $(lsb_release -is) in
        "Debian")
            DISTRIBUTION="debian"
        ;;
        "Ubuntu")
            DISTRIBUTION="ubuntu"
        ;;
        *)
            echo "Sorry, this script works only on Debian and Ubuntu distributives."
            exit 1
        ;;
    esac
}

function installation {
    clear
    echo "Welcome to Linux setup (v. $VERSION) script!"
    echo "The Git repository is available here: https://github.com/unimarijo/linux-setup."
    echo ""
    echo "You will be asked a few questions before the server will be ready."
    echo "You can leave the default options and just press enter if you are OK with them."

    echo ""
    echo "Do you want to do full upgrade of the system (it can add and remove packages)?"
    echo "TIP: Full upgrade is recommended on new systems so all packages will be up-to-date."
    echo "    1) Full upgrade the system"
    echo "    2) Packages upgrade"
    echo "    3) Don't upgrade packages"
    until [[ "$UPGRADE_CHOICE" =~ ^[1-3]$ ]]; do
        read -rp "Please choose the right option for you [1-3]: " -e -i 1 UPGRADE_CHOICE
    done
    case $UPGRADE_CHOICE in
        1)
            echo "### Doing full upgrade of the system ..."
            apt-get update && apt-get dist-upgrade -y && apt-get autoclean -y && apt-get autoremove -y
        ;;
        2)
            echo "### Packages are being upgraded ..."
            apt-get update && apt-get upgrade -y && apt-get autoclean -y && apt-get autoremove -y
        ;;
        3)
        ;;
    esac

    echo ""
    echo "Do you want to upgrade packages daily (without adding/removing any)?"
    echo "    1) Yes"
    echo "    2) No"
    until [[ "$CRON_PACKAGES_CHOICE" =~ ^[1-2]$ ]]; do
        read -rp "Please choose the right option for you [1-2]: " -e -i 1 CRON_PACKAGES_CHOICE
    done
    case $CRON_PACKAGES_CHOICE in
        1)
            printf "%s\n" "#!/bin/bash" "" "apt-get update && apt-get upgrade -y && apt-get autoremove -y && apt-get autoclean -y" > /etc/cron.daily/packages-upgrade
            chmod +x /etc/cron.daily/packages-upgrade
        ;;
        2)
        ;;
    esac

    echo ""
    echo "Do you want to do full upgrade of the system weekly and reboot it after the completion?"
    echo "    1) Yes"
    echo "    2) No"
    until [[ "$CRON_SYSTEM_CHOICE" =~ ^[1-2]$ ]]; do
        read -rp "Please choose the right option for you [1-2]: " -e -i 1 CRON_SYSTEM_CHOICE
    done
    case $CRON_SYSTEM_CHOICE in
        1)
            printf "%s\n" "#!/bin/bash" "" "apt-get update && apt-get dist-upgrade -y && apt-get autoremove -y && apt-get autoclean -y" "reboot" > /etc/cron.weekly/full-upgrade
            chmod +x /etc/cron.weekly/full-upgrade
        ;;
        2)
        ;;
    esac

    echo ""
    echo "Do you want to install UFW (simple firewall) and set it up (disallow incoming connections to all ports except OpenSSH and Mosh)?"
    echo "WARNING: It may disrupt existing SSH connections."
    echo "    1) Yes"
    echo "    2) No"
    until [[ "$UFW_CHOICE" =~ ^[1-2]$ ]]; do
        read -rp "Please choose the right option for you [1-2]: " -e -i 1 UFW_CHOICE
    done
    case $UFW_CHOICE in
        1)
            apt-get install -y ufw
            ufw allow 22 && ufw allow 60000:61000/udp && ufw --force enable
        ;;
        2)
        ;;
    esac

    echo ""
    echo "Do you want to disable password authentication for SSH?"
    echo "INFO: You must have your public key in /root/.ssh/authorized_keys in order to disable password authentication."
    echo "    1) Yes"
    echo "    2) No"
    until [[ "$PA_CHOICE" =~ ^[1-2]$ ]]; do
        read -rp "Please choose the right option for you [1-2]: " -e -i 1 PA_CHOICE
    done
    case $PA_CHOICE in
        1)
            if [ -e "/root/.ssh/authorized_keys" ]; then
                sed -i 's/#ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
                sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
                systemctl restart ssh
            else
                echo "You don't have a public key in /root/.ssh/authorized_keys, password authentication can't be disabled."
            fi
        ;;
        2)
        ;;
    esac

    echo ""
    echo "Do you want to create a new user with no password and sudo group, sudo won't require a password?"
    echo "INFO: You must have public key authentictation enabled otherwise you won't be able to log in through SSH. The public key for a new user will be copied from /root/.ssh/authorized_keys."
    echo "    1) Yes"
    echo "    2) No"
    until [[ "$USER_CHOICE" =~ ^[1-2]$ ]]; do
        read -rp "Please choose the right option for you [1-2]: " -e -i 1 USER_CHOICE
    done
    case $USER_CHOICE in
        1)
            if [ -e "/root/.ssh/authorized_keys" ]; then
                echo ""
                read -rp "Please specify a name for a new user: " NEW_USERNAME

                apt-get install -y rsync
                adduser --disabled-password --gecos "" "$NEW_USERNAME" && usermod -aG sudo "$NEW_USERNAME"
                rsync --archive --chown="$NEW_USERNAME:$NEW_USERNAME" ~/.ssh "/home/$NEW_USERNAME"
                echo "$NEW_USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
            else
                echo "You don't have public key authentication enabled, a new user with no password can't be created."
            fi
        ;;
        2)
        ;;
    esac

    echo ""
    echo "Do you want to install Docker?"
    echo "INFO: Docker is a set of platform-as-a-service products that use OS-level virtualization to deliver software in packages called containers."
    echo "    1) Yes"
    echo "    2) No"
    until [[ "$DOCKER_CHOICE" =~ ^[1-2]$ ]]; do
        read -rp "Please choose the right option for you [1-2]: " -e -i 1 DOCKER_CHOICE
    done
    case $DOCKER_CHOICE in
        1)
            echo "### Docker is being installed ..."

            case $(uname -m) in
                "x86_64") ARCHITECTURE="amd64";;
                *) ARCHITECTURE=$(uname -m);;
            esac
            apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg2
            apt-get autoremove -y docker docker-engine docker.io containerd runc
            curl -fsSL "https://download.docker.com/linux/$DISTRIBUTION/gpg" | apt-key add -
            add-apt-repository "deb [arch=$ARCHITECTURE] https://download.docker.com/linux/$DISTRIBUTION $(lsb_release -cs) stable"
            apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io
            usermod -aG docker "$NEW_USERNAME"
        ;;
        2)
        ;;
    esac

    echo ""
    echo "Do you want to install Docker Compose?"
    echo "INFO: Docker Compose is a tool for defining and running multi-container Docker applications."
    echo "    1) Yes"
    echo "    2) No"
    until [[ "$DC_CHOICE" =~ ^[1-2]$ ]]; do
        read -rp "Please choose the right option for you [1-2]: " -e -i 1 DC_CHOICE
    done
    case $DC_CHOICE in
        1)
            echo "### Docker-compose is being installed ..."
            curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
        ;;
        2)
        ;;
    esac

    if [ -n "$NEW_USERNAME" ]; then
        echo ""
        echo "Do you want to continue using system as $NEW_USERNAME?"
        echo "    1) Yes"
        echo "    2) No"
        until [[ "$SU_CHOICE" =~ ^[1-2]$ ]]; do
            read -rp "Please choose the right option for you [1-2]: " -e -i 1 SU_CHOICE
        done
        case $SU_CHOICE in
            1) su - "$NEW_USERNAME";;
            2);;
        esac
    fi
}

check_os
is_root
installation
