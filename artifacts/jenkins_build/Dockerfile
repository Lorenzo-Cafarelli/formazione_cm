FROM jenkins/jenkins:lts-jdk17

USER root

# Installiamo curl, tar e sudo
RUN apt-get update && apt-get install -y curl tar sudo && rm -rf /var/lib/apt/lists/*

# INSTALLAZIONE DOCKER CLI (Metodo Statico Universale)
ENV DOCKER_VERSION=24.0.7
RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz \
  | tar -xzC /usr/local/bin --strip-components=1 docker/docker

# Permettiamo all'utente Jenkins di usare sudo docker senza password
RUN echo "jenkins ALL=(ALL) NOPASSWD: /usr/local/bin/docker" >> /etc/sudoers

USER jenkins
