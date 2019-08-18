#!/bin/bash

VERSION=0.3.1
DOCKER_COMPOSE_VERSION=1.24.1

function isRoot {
    if [ "$EUID" -ne 0 ]; then
        echo "Sorry, you need to run this script as root."
        exit 1
    fi
}

function checkOS {
    case $(lsb_release -is) in
        "Debian")
            DISTRIBUTION="debian"
        ;;
        "Ubuntu")
            DISTRIBUTION="ubuntu"
        ;;
        *)
            echo "Sorry, this script works only on Debian or Ubuntu."
            exit 1
        ;;
    esac
}

function installation {
    clear
    echo "Welcome to Linux setup (v. $VERSION) script!"
    echo "Repository is available at GitHub: https://github.com/unimarijo/linux-setup."
    echo ""
    echo "I need to ask you a few questions."
    echo "You can leave the default options and just press enter if you are OK with them."

    echo ""
    echo "Do you want to do full upgrade of the system (it can also add or remove packagages)?"
    echo "TIP: Full upgrade is recommended on new systems."
    echo "    1) Default: full upgrade"
    echo "    2) Upgrade only"
    echo "    3) Don't upgrade"
    until [[ "$UPGRADE_CHOICE" =~ ^[1-3]$ ]]; do
        read -rp "Please choose the right option for you [1-3]: " -e -i 1 UPGRADE_CHOICE
    done
    case $UPGRADE_CHOICE in
        1)
            echo "### Packages are being upgraded and (if needed) added or removed ..."
            apt-get update && apt-get dist-upgrade -y && apt-get autoclean -y && apt-get autoremove -y
        ;;
        2)
            echo "### Packages are being upgraded ..."
            apt-get update && apt-get upgrade -y && apt-get autoclean -y && apt-get autoremove -y
        ;;
        3)
        ;;
    esac

    CRONTAB_PACKAGES_UPGRADE_STRING="25 3    * * *    root    apt-get update && apt-get upgrade -y && apt-get autoremove -y && apt-get autoclean -y"
    echo ""
    echo "Do you want to upgrade packages daily (without adding/removing any)?"
    echo "INFO: Packages will be upgraded daily at 03:25, the command will be added to the crontab."
    echo "    1) Default: yes"
    echo "    2) No"
    until [[ "$CRON_PACKAGES_CHOICE" =~ ^[1-2]$ ]]; do
        read -rp "Please choose the right option for you [1-2]: " -e -i 1 CRON_PACKAGES_CHOICE
    done
    case $CRON_PACKAGES_CHOICE in
        1)
            if ! grep -Fq "$CRONTAB_PACKAGES_UPGRADE_STRING" "/etc/crontab"; then
                printf "\n# Upgrade packages\n%s" "$CRONTAB_PACKAGES_UPGRADE_STRING" >> /etc/crontab
            else
                echo "The packages upgrade command has been already added to the crontab, the command wasn't added a second time."
            fi
        ;;
        2)
        ;;
    esac

    CRONTAB_SYSTEM_UPGRADE_STRING="47 4    * * 7    root    apt-get update && apt-get dist-upgrade -y && apt-get autoremove -y && apt-get autoclean -y && reboot"
    echo ""
    echo "Do you want to upgrade system weekly and reboot it after the completion?"
    echo "INFO: System will be upgraded on Sundays at 04:47, the command will be added to the crontab."
    echo "    1) Default: yes"
    echo "    2) No"
    until [[ "$CRON_SYSTEM_CHOICE" =~ ^[1-2]$ ]]; do
        read -rp "Please choose the right option for you [1-2]: " -e -i 1 CRON_SYSTEM_CHOICE
    done
    case $CRON_SYSTEM_CHOICE in
        1)
            if ! grep -Fq "$CRONTAB_SYSTEM_UPGRADE_STRING" "/etc/crontab"; then
                printf "\n# Upgrade system\n%s" "$CRONTAB_SYSTEM_UPGRADE_STRING" >> /etc/crontab
            else
                echo "The system upgrade command has been already added to the crontab, the command wasn't added a second time."
            fi
        ;;
        2)
        ;;
    esac

    echo ""
    echo "Do you want to install UFW (firewall) and set it up (disallow connections to all ports except OpenSSH and Mosh)?"
    echo "WARNING: It may disrupt existing SSH connections."
    echo "    1) Default: yes"
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
    echo "INFO: You have to have your public key in /root/.ssh/authorized_keys if you want to disable password authentication."
    echo "    1) Default: yes"
    echo "    2) No"
    until [[ "$PA_CHOICE" =~ ^[1-2]$ ]]; do
        read -rp "Please choose the right option for you [1-2]: " -e -i 1 PA_CHOICE
    done
    case $PA_CHOICE in
        1)
            if [ -e "/root/.ssh/authorized_keys" ]; then
                sed -i 's/#ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
                sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
                service ssh restart
            else
                echo "You don't have a public key in /root/.ssh/authorized_keys, password authentication can't be disabled."
            fi
        ;;
        2)
        ;;
    esac

    echo ""
    echo "Do you want to create a new user with no password and sudo group (sudo command won't require any password)?"
    echo "INFO: Public key for a new user will be synced with one in /root/.ssh/authorized_keys."
    echo "    1) Default: yes"
    echo "    2) No"
    until [[ "$USER_CHOICE" =~ ^[1-2]$ ]]; do
        read -rp "Please choose the right option for you [1-2]: " -e -i 1 USER_CHOICE
    done
    case $USER_CHOICE in
        1)
            if [ -e "/root/.ssh/authorized_keys" ]; then
                apt-get install -y rsync
                read -rp "Please specify a name for a new user: " NEW_USERNAME
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
    echo "    1) Default: yes"
    echo "    2) No"
    until [[ "$DOCKER_CHOICE" =~ ^[1-2]$ ]]; do
        read -rp "Please choose the right option for you [1-2]: " -e -i 1 DOCKER_CHOICE
    done
    case $DOCKER_CHOICE in
        1)
            echo "### Docker is being installed ..."
            case $(uname -m) in
                "x86_64")
                    ARCHITECTURE="amd64"
                ;;
                *)
                    ARCHITECTURE=$(uname -m)
                ;;
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
    echo "Do you want to install docker-compose?"
    echo "    1) Default: yes"
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
        echo "    1) Default: yes"
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

checkOS
isRoot
installation
