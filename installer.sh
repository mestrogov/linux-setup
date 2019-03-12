# Последняя версия Docker-Compose
DOCKER_COMPOSE_VERSION=1.23.2
# Проверяем операционную систему
case $(lsb_release -is) in
  "Debian" ) DISTRIBUTION="debian";;
  "Ubuntu" ) DISTRIBUTION="ubuntu";;
  * ) echo "### Этот скрипт может работать только с операционными системами Debian и Ubuntu :(" && exit;;
esac
# Архитектура машины
case $(uname -m) in
  "x86_64" ) ARCHITECTURE="amd64";;
  * ) ARCHITECTURE=$(uname -m);;
esac

# Обновление все пакетов
echo "### Обновление всех пакетов ..."
apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y && apt-get autoclean -y && apt-get autoremove -y

# Установка рекомендуемых и необходимых пакетов
echo "\n\n### Установка рекомендуемых и необходимых пакетов ..."
# Рекомендуемые пакеты
apt-get install ufw mosh vnstat -y
# Необходимые пакеты для Docker
apt-get install apt-transport-https ca-certificates curl software-properties-common -y
if [ "$DISTRIBUTION" = "debian" ]; then
  apt-get install gnupg2 -y
else
  apt-get install gnupg-agent -y
fi

# Базовая настройка Firewall
echo "\n\n### Базовая настройка Firewall ..."
echo "### Запрет на входящие подключения ко всем портам, кроме порта OpenSSH (22/tcp), Mosh (60000:61000/udp)."
ufw allow 22 && ufw allow 60000:61000/udp && ufw enable
ufw status verbose

# Отключение SSH аутентификации с помощью пароля
echo "\n\n### Отключение SSH аутентификации с помощью пароля ..."
# Взято отсюда: https://gist.github.com/parente/0227cfbbd8de1ce8ad05#gistcomment-2740011
sed -i 's/#ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
service ssh restart

# Создание нового пользователя, добавление его в sudo группу
echo "\n\n### Создание нового пользователя ..."
read -p "Укажите имя для нового пользователя: " username
adduser --disabled-password --gecos "" $username && usermod -aG sudo $username
# Клонирование SSH ключа root пользователя к новому пользователю
rsync --archive --chown=$username:$username ~/.ssh /home/$username
# Добавляем пользователя в /etc/sudoers, чтобы sudo запускалось без пароля
echo "$username ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Установка Docker
echo "\n\n### Установка Docker ..."
apt-get remove docker docker-engine docker.io containerd runc
curl -fsSL "https://download.docker.com/linux/$DISTRIBUTION/gpg" | apt-key add -
add-apt-repository "deb [arch=$ARCHITECTURE] https://download.docker.com/linux/$DISTRIBUTION $(lsb_release -cs) stable"
apt-get update && apt-get install docker-ce docker-ce-cli containerd.io -y
# Добавляем пользователя в Docker, чтобы он мог использовать docker без sudo
usermod -aG docker $username

# Установка Docker-Compose
echo "\n\n### Установка Docker-Compose ..."
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Завершение
echo "\n\n### Начальная сервера завершена."
echo "\033[0;31m### Помните: этот скрипт предназначен только для начальной настройки, запускать его второй раз на одном и том же сервере не нужно!\033[0m"
# Удаление скрипта, ибо он предназначен только для начальной настройки
rm installer.sh
read -p "Хотите ли вы переавторизироваться в системе как пользователь $username? (y/N) " decision
if [ "$decision" = "y" ] || [ "$decision" = "Y" ]; then
  su $username && cd ~
fi
