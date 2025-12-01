FROM ubuntu:latest
RUN apt-get update && apt-get install -y openssh-server sudo python3
RUN mkdir /var/run/sshd
# UTENTE CON PASSWORD: Usa l'hash della password definita nel vault (con default di sicurezza)
RUN useradd -m -s /bin/bash -p '$6$rounds=656000$JWuoPpU0Th4ayVly$dgkQEObEw35ry2I5KHl.1L288geY7pROGbaMfxdCS2E2VYsCl5AaG9lYPM4eZh85HAlmUnDbtbzV.Fofu7Chz/' devops

# Sudo senza password (opzionale, ora che hai la password potresti toglierlo)
RUN echo 'devops ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/devops

# Setup SSH
RUN mkdir -p /home/devops/.ssh
COPY authorized_keys /home/devops/.ssh/authorized_keys
RUN chown -R devops:devops /home/devops/.ssh && chmod 600 /home/devops/.ssh/authorized_keys
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
