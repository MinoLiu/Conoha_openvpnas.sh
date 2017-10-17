#!/bin/sh

echo "Add new username passwd and change port"
read -p "user(default debian):" user
if [ -z "$user" ]; then
        user=debian
fi

while [ 1 ]; do
        stty -echo
        read -p "Enter new UNIX password:" password && echo
        read -p "Retype new UNIX password:" confirmPassword && echo
        stty echo
        if [ "$password" = "$confirmPassword" ]; then
                if [ -z "$password" ]; then
                        echo "No password supplied"
                else
                        break
                fi
        else
                echo "Sorry, passwords do not match"
        fi
done
echo "Port recommended range is 10000 ~ 65535"
read -p "port(default 22):" port
if [ -z "$port" ] || [ "$port" -gt 65535 -a "$port" -lt 1 ]; then
        port=22
fi
echo "port set to $port"
read -p "ethernet-interface(default eth0):" interface
if [ -z "$interface" ]; then
        interface=eth0
fi
read -p "Ready to start?(Y/N)" confirm

run(){
        # install git curl fail2ban
        apt-get update && apt-get install -y git curl fail2ban
        # adduser
        useradd -ms /bin/bash $user && echo "$user:$password" | chpasswd && adduser $user sudo
        # change ssh port
        sed -i "s/^#\(Port\).*/\1 $port/g" /etc/ssh/sshd_config
        # disable root login
        sed -i "s/^\(PermitRootLogin\).*/\1 no/g" /etc/ssh/sshd_config
        # restart ssh
        service ssh restart
        # config fail2ban
        sed -i "s/\(port *=.*\)ssh/\1$port/g" /etc/fail2ban/jail.conf
        fail2ban-client reload
        # install docker
        curl -sSL get.docker.com | sh
        adduser $user docker
        # install docker-compose
        curl -L https://github.com/docker/compose/releases/download/1.16.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose

        # change user
        sudo -u $user -H sh -c "cd && git clone 'https://github.com/Sean2525/Conoha_openvpnas.sh.git' && \
        mv Conoha_openvpnas.sh openvpn"

        cd /home/$user/openvpn
        #set environment for docker-compose.yml
        uid=$(id $user | sed "s/.*uid=\([0-9]*\).*/\1/g")
        gid=$(id $user | sed "s/.*gid=\([0-9]*\).*/\1/g")
        sed -i "s/\(PGID=\).*/\1$gid/g" docker-compose.yml
        sed -i "s/\(PUID=\).*/\1$uid/g" docker-compose.yml
        sed -i "s/\(INTERFACE=\).*/\1$interface/g" docker-compose.yml
        # docker run openvpns
        docker-compose up -d
        echo "+ sleep 10"
        sleep 10
        # delete admin user in as.conf
        sed -i "s/^\(boot_pam_users.0=admin.*\)/# \1/g" ./config/etc/as.conf
        echo "openvpnas is running, start setting"
        echo https://$(ifconfig $interface | grep "inet " | sed 's/^.*inet \([0-9\.]*\).*/\1/g'):943/admin
        echo "Openvpn username: \033[31madmin\033[0m , password: \033[31mpassword\033[0m"
        echo "\033[31mAdd local user and delete admin\033[0m"
        while [ 1 ]; do
                read -p "Did you finish the configuration?(Y/N)" YES
                if [ "$YES" = "Y" -o "$YES" = "y" ]; then
                        docker-compose restart
                        break
                fi
        done
        echo "Complete!"
        echo "Next login vps please use username:\033[31m$user\033[0m and your passwd at port:\033[31m$port\033[0m"
        echo "Because the installed the fail2ban, so the login failed 5 times will be blocked for 10 minutes"
        echo "Openvpnas connect url:"
        echo https://$(ifconfig $interface | grep "inet " | sed 's/^.*inet \([0-9\.]*\).*/\1/g'):943
        exit 0
}



if [ "$confirm" = "Y" -o "$confirm" = "y"  ]; then
        run
else
        exit 0
fi