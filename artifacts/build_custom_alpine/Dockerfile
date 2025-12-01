FROM alpine:latest
RUN apk add --no-cache openssh sudo python3 shadow bash
RUN ssh-keygen -A
# UTENTE CON PASSWORD: Usa l'hash della password definita nel vault (con default di sicurezza)
RUN useradd -m -s /bin/bash -p '$6$rounds=656000$AIqx2K4J.LB5.gA5$gpW11bN2RrriyfdBqNo1eAM7EynigH1YczszH2bm7KI4/wyaOmtSxIdLz7t0lNztW9gPdb.QH6bXeM3vrqYF60' devops

RUN echo 'devops ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/devops

# Setup SSH
RUN mkdir -p /home/devops/.ssh
COPY authorized_keys /home/devops/.ssh/authorized_keys
RUN chown -R devops:devops /home/devops/.ssh && chmod 600 /home/devops/.ssh/authorized_keys
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
