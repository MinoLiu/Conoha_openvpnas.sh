#!/usr/bin/env bash


read -p "user(default user):" user
if [[ $user == "" ]]; then
        user=user
fi

while [ 1 ]; do
        stty -echo
        read -p "password: " password && echo ""
        read -p "confirm password: " confirmPassword && echo ""
        stty echo
        if [[ $password == $confirmPassword ]]; then
                if [[ $password == "" ]]; then
                        echo "password can not be none"
                else
                        break
                fi
        else
                echo "password not match"
        fi
done
read -p "port(default 22):" port
if [[ $port == "" ]] || [[ $port =~ [^0-9] ]]; then
        port=22
fi
echo "port set to $port"

read -p "ethernet-interface(default eth0):" interface
if [[ $interface == "" ]]; then
        interface=eth0
fi
read -p "Ready to start?(Y/N)" confirm

run(){
        apt-get update && apt-get install -y git curl
        # adduser
        useradd -ms /bin/bash $user && echo "$user:$password" | chpasswd && adduser $user sudo
        # change ssh port
        sed -i "s/^#\(Port\).*/\1 $port/g" /etc/ssh/sshd_config
        # disable root login
        sed -i "s/^\(PermitRootLogin\).*/\1 no/g" /etc/ssh/sshd_config
        # restart ssh
        service ssh restart

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
        docker-compose up -d
        echo "+ sleep 10"
        sleep 10
        sed -i "s/^\(boot_pam_users.0=admin.*\)/# \1/g" ./config/etc/as.conf
        echo "openvpn is running, set up the config at"
        echo https://$(ifconfig $interface | grep "inet " | sed 's/^.*inet \([0-9\.]*\).*/\1/g'):943/admin
        echo "username: admin , password: password"
        echo "add local user and delete admin"
        while [ 1 ]; do
                read -p "Did you finish the configuration?(Y/N)" YES
                if [[ $YES =~ ^[Yy] ]]; then
                        docker-compose restart
                        break
                fi
        done
        echo "Complete!"
        exit 0
}



if [[ $confirm =~ ^[Yy]  ]]; then
        run
else
        exit 0
fi