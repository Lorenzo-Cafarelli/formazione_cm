FROM alpine:latest
# Installa SSH, Sudo, Python e Shadow (per useradd standard)
RUN apk add --no-cache openssh sudo python3 shadow bash
# Genera host keys (CRUCIALE per Alpine, altrimenti sshd non parte)
RUN ssh-keygen -A
# Crea utente e configura sudo
RUN useradd -m -s /bin/bash ansible_user
RUN echo 'ansible_user ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ansible_user
# Imposta chiavi SSH
RUN mkdir -p /home/ansible_user/.ssh
COPY authorized_keys /home/ansible_user/.ssh/authorized_keys
RUN chown -R ansible_user:ansible_user /home/ansible_user/.ssh && chmod 600 /home/ansible_user/.ssh/authorized_keys
# Espone porta ed avvia
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
