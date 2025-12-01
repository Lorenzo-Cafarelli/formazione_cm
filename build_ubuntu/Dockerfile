FROM ubuntu:latest
# Installa SSH, Sudo e Python (per Ansible future)
RUN apt-get update && apt-get install -y openssh-server sudo python3
# Configura SSHD: crea directory necessaria
RUN mkdir /var/run/sshd
# Crea utente e configura sudo senza password
RUN useradd -m -s /bin/bash ansible_user
RUN echo 'ansible_user ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ansible_user
# Imposta chiavi SSH
RUN mkdir -p /home/ansible_user/.ssh
COPY authorized_keys /home/ansible_user/.ssh/authorized_keys
RUN chown -R ansible_user:ansible_user /home/ansible_user/.ssh && chmod 600 /home/ansible_user/.ssh/authorized_keys
# Espone porta ed avvia
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
