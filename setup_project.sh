#!/bin/bash

# 1. Creazione della struttura delle directory
echo "Creazione struttura directory..."
mkdir -p roles/local_registry/{tasks,defaults}
mkdir -p roles/image_builder/tasks
mkdir -p roles/container_runner/tasks
mkdir -p artifacts

# 2. Creazione del Playbook Principale (site.yml)
echo "Creazione site.yml..."
cat > site.yml << 'EOF'
---
- name: Step 3 - Orchestrazione Container con Ruoli
  hosts: localhost
  connection: local
  gather_facts: no
  
  vars:
    # --- CONFIGURAZIONE GLOBALE ---
    # Scegli 'docker' o 'podman'
    container_runtime: "docker" 
    
    # Parametri generali
    lab_user: "devops"
    ssh_key_path: "./artifacts/lab_key"
    registry_host: "localhost"
    registry_port: 5000

    # Immagini da costruire
    build_images:
      - name: "custom_ubuntu"
        os_type: "ubuntu"
        tag: "v1"
      - name: "custom_alpine"
        os_type: "alpine"
        tag: "v1"

    # Container da lanciare
    deploy_containers:
      - name: "srv_ubuntu_01"
        image_name: "custom_ubuntu"
        image_tag: "v1"
        host_port: 2201
      - name: "srv_alpine_01"
        image_name: "custom_alpine"
        image_tag: "v1"
        host_port: 2202

  roles:
    - role: local_registry
      vars:
        registry_name: "my_local_registry"
    
    - role: image_builder
    
    - role: container_runner
EOF

# 3. Creazione Ruolo: LOCAL REGISTRY
echo "Creazione ruolo local_registry..."

# defaults/main.yml
cat > roles/local_registry/defaults/main.yml << 'EOF'
---
registry_name: "local_registry"
registry_port: 5000
container_runtime: "docker"
EOF

# tasks/main.yml
cat > roles/local_registry/tasks/main.yml << 'EOF'
---
- name: Verifica stato del registry container
  command: "{{ container_runtime }} ps -q -f name={{ registry_name }}"
  register: registry_check
  changed_when: false

- name: Avvia il Local Registry
  command: >
    {{ container_runtime }} run -d 
    -p {{ registry_port }}:5000 
    --name {{ registry_name }} 
    --restart always 
    registry:2
  when: registry_check.stdout == ""

- name: Attendi che il registry sia pronto
  wait_for:
    port: "{{ registry_port }}"
    delay: 2
EOF

# 4. Creazione Ruolo: IMAGE BUILDER
echo "Creazione ruolo image_builder..."

# tasks/main.yml
cat > roles/image_builder/tasks/main.yml << 'EOF'
---
- name: Crea directory artifacts (sicurezza)
  file:
    path: "./artifacts"
    state: directory

- name: Genera chiavi SSH per i container
  community.crypto.openssh_keypair:
    path: "{{ ssh_key_path }}"
    type: ed25519
  register: ssh_key_gen

- name: Crea directory di build per le immagini
  file:
    path: "./artifacts/build_{{ item.name }}"
    state: directory
  loop: "{{ build_images }}"

- name: Copia chiave pubblica nei contesti di build
  copy:
    src: "{{ ssh_key_path }}.pub"
    dest: "./artifacts/build_{{ item.name }}/authorized_keys"
  loop: "{{ build_images }}"

- name: Genera Dockerfile per Ubuntu
  copy:
    dest: "./artifacts/build_{{ item.name }}/Dockerfile"
    content: |
      FROM ubuntu:latest
      RUN apt-get update && apt-get install -y openssh-server sudo python3
      RUN mkdir /var/run/sshd
      RUN useradd -m -s /bin/bash {{ lab_user }}
      RUN echo '{{ lab_user }} ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/{{ lab_user }}
      RUN mkdir -p /home/{{ lab_user }}/.ssh
      COPY authorized_keys /home/{{ lab_user }}/.ssh/authorized_keys
      RUN chown -R {{ lab_user }}:{{ lab_user }} /home/{{ lab_user }}/.ssh && chmod 600 /home/{{ lab_user }}/.ssh/authorized_keys
      EXPOSE 22
      CMD ["/usr/sbin/sshd", "-D"]
  loop: "{{ build_images }}"
  when: item.os_type == 'ubuntu'

- name: Genera Dockerfile per Alpine
  copy:
    dest: "./artifacts/build_{{ item.name }}/Dockerfile"
    content: |
      FROM alpine:latest
      RUN apk add --no-cache openssh sudo python3 shadow bash
      RUN ssh-keygen -A
      RUN useradd -m -s /bin/bash {{ lab_user }}
      RUN echo '{{ lab_user }} ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/{{ lab_user }}
      RUN mkdir -p /home/{{ lab_user }}/.ssh
      COPY authorized_keys /home/{{ lab_user }}/.ssh/authorized_keys
      RUN chown -R {{ lab_user }}:{{ lab_user }} /home/{{ lab_user }}/.ssh && chmod 600 /home/{{ lab_user }}/.ssh/authorized_keys
      EXPOSE 22
      CMD ["/usr/sbin/sshd", "-D"]
  loop: "{{ build_images }}"
  when: item.os_type == 'alpine'

- name: Build delle Immagini
  command: >
    {{ container_runtime }} build 
    -t {{ registry_host }}:{{ registry_port }}/{{ item.name }}:{{ item.tag }} 
    ./artifacts/build_{{ item.name }}
  loop: "{{ build_images }}"
  changed_when: true

- name: Push sul Registry Locale
  command: >
    {{ container_runtime }} push 
    {{ tls_flag | default('') }}
    {{ registry_host }}:{{ registry_port }}/{{ item.name }}:{{ item.tag }}
  loop: "{{ build_images }}"
  vars:
    tls_flag: "{{ '--tls-verify=false' if container_runtime == 'podman' else '' }}"
  changed_when: true
EOF

# 5. Creazione Ruolo: CONTAINER RUNNER
echo "Creazione ruolo container_runner..."

# tasks/main.yml
cat > roles/container_runner/tasks/main.yml << 'EOF'
---
- name: Pulizia container esistenti (se presenti)
  command: "{{ container_runtime }} rm -f {{ item.name }}"
  loop: "{{ deploy_containers }}"
  ignore_errors: true
  changed_when: false

- name: Run dei Container dai Registry
  command: >
    {{ container_runtime }} run -d
    --name {{ item.name }}
    --restart always
    -p {{ item.host_port }}:22
    {{ tls_flag | default('') }}
    {{ registry_host }}:{{ registry_port }}/{{ item.image_name }}:{{ item.image_tag }}
  loop: "{{ deploy_containers }}"
  vars:
    tls_flag: "{{ '--tls-verify=false' if container_runtime == 'podman' else '' }}"

- name: Info Accesso
  debug:
    msg: "Container {{ item.name }} accessibile via: ssh -i {{ ssh_key_path }} -p {{ item.host_port }} {{ lab_user }}@localhost"
  loop: "{{ deploy_containers }}"
EOF

echo "--- Setup Completato ---"
echo "La struttura delle cartelle è pronta."
echo "Esegui il playbook con: ansible-playbook site.yml"