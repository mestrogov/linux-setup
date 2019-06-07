#!/bin/bash

VERSION=0.2.0
DOCKER_COMPOSE_VERSION=1.24.0

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
            echo "Sorry, this script works only with Debian and Ubuntu distributives :("
            exit 1
        ;;
    esac
}

function installation {
    clear
    echo "Welcome to Linux server setup (v. $VERSION) out there!"
    echo "Thanks for using it, I really appreciate it!"
    echo "Repository is available at GitHub: https://github.com/unimarijo/linux-setup."
    echo ""
    echo "I need to ask you a few questions."
    echo "You can leave the default options and just press enter if you are OK with them."

    if [ -e "/root/.linux_setup_installation_executed" ]; then
        echo ""
        echo "Installation proccess has been run before, do you want to run it again?"
        echo "WARNING: Running installation proccess multiple times can cause abnormal situations."
        echo "    1) Default: no"
        echo "    2) Yes"
        until [[ "$INSTALLATION_CHOICE" =~ ^[1-2]$ ]]; do
            read -rp "Please choose the right option for you [1-2]: " -e -i 1 INSTALLATION_CHOICE
        done
        case $INSTALLATION_CHOICE in
            1) return ;;
            2) ;;
        esac
    fi

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

    DEFAULT_PACKAGES="mosh vnstat"
    echo ""
    echo "Do you want to install any additional packages?"
    echo "INFO: You can install any other packages just by specifying them with space after each (e.g. mosh vnstat) instead of the number of option."
    echo "    1) Default: $DEFAULT_PACKAGES"
    echo "    2) Don't install anything"
    read -rp "Please choose the right option for you: " -e -i 1 PACKAGES_CHOICE
    case $PACKAGES_CHOICE in
        "1")
            echo "### Default packages ($DEFAULT_PACKAGES) are being installed ..."
            apt-get install -y $DEFAULT_PACKAGES
        ;;
        "2")
        ;;
        *)
            echo "### Specified packages ($PACKAGES_CHOICE) are being installed ..."
            apt-get install -y $PACKAGES_CHOICE
        ;;
    esac

    CRONTAB_UPGRADE_STRING="42 3    * * *    root    apt-get update && apt-get upgrade -y && apt-get autoclean -y && apt-get autoremove -y"
    echo ""
    echo "Do you want to upgrade packages everyday (without adding/removing any)?"
    echo "INFO: Packages will be upgraded everyday at 03:42 at night, the upgrade command will be added to the crontab."
    echo "    1) Default: yes"
    echo "    2) No"
    until [[ "$CRON_CHOICE" =~ ^[1-2]$ ]]; do
        read -rp "Please choose the right option for you [1-2]: " -e -i 1 CRON_CHOICE
    done
    case $CRON_CHOICE in
        1)
            if [ ! -z $(grep "$CRONTAB_UPGRADE_STRING" "/etc/crontab") ]; then
                printf "\n# Packages upgrading\n$CRONTAB_UPGRADE_STRING" >> /etc/crontab
            else
                echo "The packages upgrade command has been already added to the crontab, command wasn't added a second time."
            fi
        ;;
        2)
        ;;
    esac

    echo ""
    echo "Do you want to install UFW and set it up (block all ports except OpenSSH and Mosh)?"
    echo "    1) Default: yes"
    echo "    2) No"
    until [[ "$UFW_CHOICE" =~ ^[1-2]$ ]]; do
        read -rp "Please choose the right option for you [1-2]: " -e -i 1 UFW_CHOICE
    done
    case $UFW_CHOICE in
        1)
            apt-get install -y ufw
            ufw allow 22 && ufw allow 60000:61000/udp && ufw enable
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
                echo "You don't have a public key in /root/.ssh/authorized_keys, password authentication wasn't disabled."
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
                read -p "Choose a name for a new user: " NEW_USERNAME
                adduser --disabled-password --gecos "" $NEW_USERNAME && usermod -aG sudo $NEW_USERNAME
                rsync --archive --chown=$NEW_USERNAME:$NEW_USERNAME ~/.ssh /home/$NEW_USERNAME
                echo "$NEW_USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
            else
                echo "You don't have public key authentication enabled, a new user with no password wasn't created."
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
            usermod -aG docker $NEW_USERNAME
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

    # Сreate a file so the script can determine that installation proccess has been executed before
    touch "/root/.linux_setup_installation_executed"

    if [ ! -z "$NEW_USERNAME" ]; then
        echo ""
        echo "Do you want to continue using system as $NEW_USERNAME?"
        echo "    1) Default: yes"
        echo "    2) No"
        until [[ "$SU_CHOICE" =~ ^[1-2]$ ]]; do
            read -rp "Please choose the right option for you [1-2]: " -e -i 1 SU_CHOICE
        done
        case $SU_CHOICE in
            1) su $NEW_USERNAME;;
            2);;
        esac
    fi

    echo ""
    echo "Thanks for using me, bye!"
}

checkOS
isRoot
installation
