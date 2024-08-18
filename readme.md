# RHEL 8 Password less ssh configuration between Docker Containers 
Several techniques can be used to send or receive information or data from one container to another, Like:

- mounting a shared disk on the host and shared that host path to exchange files or information between containers
- Making use of external messaging queues such as
  - ActiveMq and
  - Kafka
- We are able to obtain information on port 80 if we are executing web applications within the container.

However some programs require or a application configured in clustered environment required SSH protocol-based communication to connect and share data or information. 
Like such as **scp**, **Ansible**, **RSYNC** and Python library **paramiko** used SSH protocol on port 22 to communicate with other servers.

## Let's start to write Dockerfile first 

- I am using here RHEL 8 as base image 
```
FROM redhat/ubi8
```

- Installing packages, speciall openssh-server and openssh-client is required 
```
RUN dnf -y install openssh-clients openssh-server iputils
```

- Root user is not recomonded for password less ssh communication. So, I am adding here a test user or in real case scenario it can be a application user with password 
```
RUN useradd testuser
RUN echo 'testdocker:docker123' | chpasswd
```

- Creading sshd service file  
```
RUN mkdir /etc/systemd/system/sshd.service.d/ && echo -e '[Service]\nRestart=always' > /etc/systemd/system/sshd.service.d/sshd.conf
```

- Updating parameters in `sshd_config` file 
```
RUN sed -i'' -e's/^#PermitRootLogin prohibit-password$/PermitRootLogin yes/' /etc/ssh/sshd_config \
        && sed -i'' -e's/^#PasswordAuthentication yes$/PasswordAuthentication yes/' /etc/ssh/sshd_config \
        && sed -i'' -e's/^#PermitEmptyPasswords no$/PermitEmptyPasswords yes/' /etc/ssh/sshd_config \
        && sed -i'' -e's/^UsePAM yes/UsePAM no/' /etc/ssh/sshd_config
```

- Port for ssh communication 
```
EXPOSE 22
```

- SSH key genration 
```
RUN ssh-keygen -A
```

- This is a crucial part of the setup for password-less ssh. In this case, copies of `id_rsa.pub` must be made to `authorised_keys` in all Docker images. These RSA keys need to be generated in advance from any RHEL 8 container and kept on the host for further use in other image creations. At the time of creating images, these keys will be copied to the `/home/<user>/.ssh/` folder of the user.
```
RUN mkdir /home/testuser/.ssh
COPY ./ssh/* /home/testuser/.ssh/
COPY ./ssh/id_rsa.pub /home/testuser/.ssh/authorized_keys
RUN chown -R testuser:testuser /home/testuser; chmod 600 /home/testuser/.ssh/*
```

- Finally, sshd service needs to be started while the container is being created.
```
CMD nohup /usr/sbin/sshd -D
```

This is the end of Dockerfile.
 

## Creation of Docker Network object  
Although docker used it's own default network system and it provides IP address to every container. But these IP address are based on DHCP and can be changed every time when container created 
To provide the static IP address to container, a docker network object need to be created as below: 
```
docker network create --driver=bridge --subnet=172.20.0.0/16 --gateway=172.20.0.1 app-network
```

All set, so, docker file need to be build. 
To build a docker file, we need to keep Dockerfile and all other required files on same folder  
Here we need to create a folder ssh. Files `id_rsa` and `id_rsa.pub` need to put there. 

Now, Build command 
```
docker build -t password-less-cluster .
```

If build is successfull. Then containers need to be created: 
**Server1**
```
docker run -t -d --name server1 --hostname server1 --net appnetwork --ip 172.20.0.3 -p 22:22 password-less-cluster
c70d6fc1fb82b98ca131798befd1ba1760f71c240aecc15535980060ab5186f2
```

**Server2**
```
C:\Users\skt31\Documents\total_logs\password_less>docker run -t -d --name server2 --hostname server2 --net appnetwork --ip 172.20.0.4 -p 2222:22 password-less-cluster
d02f7b57ef1a0d7a3af4d1572ce05d1b2fa2e544c61ed25a3ed2d61822fb2c02
```

**check IP address of container**
``` 
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' server1
`'172.20.0.3'`

docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' server2
`'172.20.0.4'`
```

We must obtain any server's command prompt in order to conduct testing:
```
docker exec -it server1 /bin/bash
```

First, switch from root user to the test / app user and run the ssh command from the command prompt. 
``` 
[root@server1 /]# `su - testuser`
[testuser@server1 ~]$ `ssh 172.20.0.4`
The authenticity of host '172.20.0.4 (172.20.0.4)' can't be established.
ECDSA key fingerprint is SHA256:XY4HyVPMBDvgJzDKkTJGUSn/DGC2NybxGCd5iH2bWro.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '172.20.0.4' (ECDSA) to the list of known hosts.
[testuser@server2 ~]$ 
```

**Successful** so now exit 

``` 
[testuser@server2 ~]$  exit
```
