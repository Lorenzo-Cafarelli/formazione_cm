#!/bin/bash

echo "Configurazione Step 5 - Jenkins (Fix macOS Network)..."

# 1. Creazione cartelle
mkdir -p roles/jenkins_stack/{tasks,defaults,files}

# 2. Creazione Dockerfile per Jenkins
# Usiamo l'installazione manuale dei binari Docker (Metodo Statico)
cat > roles/jenkins_stack/files/Dockerfile.jenkins << 'EOF'
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
EOF

# 3. Task Ansible per il ruolo Jenkins
# MODIFICA IMPORTANTE: Rimosso network host, aggiunto port mapping e host.docker.internal
cat > roles/jenkins_stack/tasks/main.yml << 'EOF'
---
- name: Crea directory di build per Jenkins
  file:
    path: "./artifacts/jenkins_build"
    state: directory

- name: Copia il Dockerfile custom
  copy:
    src: "Dockerfile.jenkins"
    dest: "./artifacts/jenkins_build/Dockerfile"

- name: Build immagine Jenkins Ops
  command: docker build -t my-jenkins-ops:latest ./artifacts/jenkins_build
  changed_when: true

- name: Rimuovi vecchio container Jenkins
  command: docker rm -f jenkins_server
  ignore_errors: true
  changed_when: false

- name: Avvia Jenkins Server (Mac Compatible)
  command: >
    docker run -d 
    --name jenkins_server 
    --restart always
    -p 8080:8080 
    -p 50000:50000
    --add-host=host.docker.internal:host-gateway
    -v /var/run/docker.sock:/var/run/docker.sock
    my-jenkins-ops:latest
EOF

# 4. Aggiunta ruolo al site.yml
if ! grep -q "jenkins_stack" site.yml; then
cat >> site.yml << 'EOF'

    - role: jenkins_stack
EOF
fi

echo "Setup Jenkins completato (Fix per macOS)."
echo "Esegui 'ansible-playbook --ask-vault-pass site.yml' per applicare."