FROM redhat/ubi8

RUN echo 'root:docker123' |chpasswd

RUN dnf -y install openssh-clients openssh-server iputils

RUN useradd testuser
RUN echo 'testdocker:docker123' | chpasswd

RUN mkdir /etc/systemd/system/sshd.service.d/ && echo -e '[Service]\nRestart=always' > /etc/systemd/system/sshd.service.d/sshd.conf

RUN sed -i'' -e's/^#PermitRootLogin prohibit-password$/PermitRootLogin yes/' /etc/ssh/sshd_config \
        && sed -i'' -e's/^#PasswordAuthentication yes$/PasswordAuthentication yes/' /etc/ssh/sshd_config \
        && sed -i'' -e's/^#PermitEmptyPasswords no$/PermitEmptyPasswords yes/' /etc/ssh/sshd_config \
        && sed -i'' -e's/^UsePAM yes/UsePAM no/' /etc/ssh/sshd_config



EXPOSE 22

## to remove error 
## sshd: no hostkeys available -- exiting.
RUN ssh-keygen -A
#RUN  nohup /usr/sbin/sshd -D &

RUN mkdir /home/testuser/.ssh
COPY ./ssh/* /home/testuser/.ssh/
COPY ./ssh/id_rsa.pub /home/testuser/.ssh/authorized_keys
RUN chown -R testuser:testuser /home/testuser; chmod 600 /home/testuser/.ssh/*


#USER testuser 

#WORKDIR /home/testuser/

CMD nohup /usr/sbin/sshd -D

