# Formazione CM - Track 3

Il progetto integra tecnologie industry-standard come Ansible, Docker (con supporto sperimentale per Podman) e Jenkins. L'obiettivo finale è orchestrare l'intero ciclo di vita del software, dalla creazione di un'infrastruttura di registro locale fino al deployment continuo tramite pipeline CI/CD, simulando un ambiente di produzione reale su macchina locale.

## Prerequisiti

### Prerequisiti Tecnici

Per eseguire correttamente i playbook e gli script contenuti in questo progetto, l'ambiente locale deve disporre di:

    - Ansible Core: Necessario per l'esecuzione dei playbook. È fondamentale che sia configurato per utilizzare l'interprete Python corretto.

    - Docker Desktop: Assicurarsi che il socket Docker sia accessibile.

    - Python 3: Ambiente di runtime per Ansible e le librerie di supporto.

    - Librerie Python:

        - docker: SDK Python per Docker, necessario affinché i moduli Ansible possano comunicare con il demone Docker.

        - passlib: Libreria crittografica necessaria per la gestione delle password cifrate con Ansible Vault.

## Struttura del Progetto

Il progetto è organizzato in Ruoli Ansible per garantire modularità e riutilizzo del codice.

.
├── site.yml                 # Playbook principale di orchestrazione
├── secrets.yml              # File cifrato con Ansible Vault (credenziali)
├── setup_jenkins.sh         # Script di inizializzazione per l'ambiente Jenkins
└── roles/
    ├── local_registry/      # Ruolo per la gestione del Registry locale
    ├── image_builder/       # Ruolo per la Build e Push delle immagini (Ubuntu/Alpine)
    ├── container_runner/    # Ruolo per il Deployment dei container
    └── jenkins_stack/       # Ruolo per il setup del server Jenkins containerizzato


# STEP 1 - Creare il Primo Playbook

Il primo passo fondamentale è stato la creazione di un'infrastruttura locale per la gestione degli artefatti (immagini Docker). Invece di dipendere esclusivamente da Docker Hub, è stato configurato un Registry Privato Locale.

## Dettagli Implementativi

    - Registry Container: Viene distribuito un container basato sull'immagine ufficiale registry:2.

    - Port Mapping Strategico: Il servizio è esposto sulla porta 5050 dell'host. Questa scelta non è casuale: serve a evitare conflitti noti con il servizio "AirPlay Receiver" presente sui sistemi macOS moderni, che occupa nativamente la porta 5000.

    - Astrazione del Runtime: I task Ansible sono stati scritti per essere agnostici rispetto al container engine sottostante, supportando sia i moduli docker_image che podman_image.

    - Sicurezza del Registry: Per facilitare l'ambiente di laboratorio, il registry è configurato senza autenticazione TLS, accessibile via localhost.

# STEP 2 - Creare Build di container

In questa fase, l'obiettivo è stato creare container che si comportino come vere e proprie macchine virtuali ("pet"), accessibili via SSH e amministrabili, pur mantenendo la leggerezza dei container.

## Specifiche delle Immagini

Sono state create definizioni per due sistemi operativi distinti: Ubuntu e Alpine Linux. Entrambi i container sono configurati per soddisfare requisiti stringenti:

    - Server SSH Attivo: Installazione e configurazione del demone sshd in ascolto sulla porta standard 22.

    - Utente Non-Root: Creazione di un utente operativo denominato devops per evitare l'uso diretto di root.

    - Accesso tramite Chiave Pubblica: Iniezione delle chiavi SSH autorizzate durante la fase di build, permettendo l'accesso immediato senza password.

    - Privilegi Sudo: Configurazione del file sudoers per permettere all'utente devops di elevare i propri privilegi quando necessario.

Nota su Alpine Linux: Essendo estremamente minimale, ha richiesto passaggi aggiuntivi rispetto a Ubuntu. È stato necessario installare il pacchetto shadow per la gestione degli utenti e generare esplicitamente le host keys SSH (ssh-keygen -A) che, a differenza di Ubuntu, non vengono create automaticamente all'installazione del pacchetto openssh.

# STEP 3 - Creazione di un ruolo

Il codice è stato ristrutturato trasformando i task singoli in Ruoli Ansible riutilizzabili e parametrici. È stato introdotto un ciclo completo di Build, Push e Run.

## Definizione dei Ruoli Ansible

L'automazione è stata suddivisa in tre ruoli distinti per garantire la separazione delle responsabilità e la riutilizzabilità del codice:

    - local_registry: Questo ruolo si occupa esclusivamente dell'infrastruttura del registry.

        - Verifica proattiva dello stato del container registry.

        - Avvia il container registry:2 se non presente.

        - Gestisce il mapping della porta (default 5050) per evitare conflitti con servizi di sistema (es. AirPlay su macOS).

    - image_builder: Questo ruolo funge da motore di Continuous Integration.

        - Genera le chiavi SSH univoche (ED25519) per l'accesso sicuro ai container.

        - Crea dinamicamente i Dockerfile per le diverse distribuzioni (Ubuntu/Alpine) basandosi sui template definiti nei task e iniettando le configurazioni necessarie.

        - Esegue la build delle immagini Docker.

        - Effettua il tag e il push delle immagini verso il registry locale (localhost:5050), rendendole disponibili per il deployment.

    - container_runner: Questo ruolo gestisce il Continuous Deployment.

        - Esegue la pulizia dei vecchi container per evitare conflitti di nomi e garantire un ambiente pulito.

        - Effettua il pull delle immagini aggiornate dal registry locale.

        - Avvia i nuovi container applicando la logica di port mapping (es. porta 22 container -> porta 2201 host) definita nelle variabili di inventario, permettendo l'esecuzione parallela di più istanze senza conflitti di porta.

## Workflow Implementato

Il flusso di lavoro automatizzato segue questi passaggi logici:

    - Build: Creazione delle immagini locali dai Dockerfile generati dinamicamente.

    - Tag: Assegnazione di un tag specifico per il versionamento.

    - Push: Caricamento delle immagini nel Registry Locale (localhost:5050).

    - Run: Scaricamento (Pull) delle immagini dal registry e avvio dei container.

## Gestione dei Conflitti di Porta

Il ruolo container_runner è progettato per evitare conflitti. Poiché tutti i container espongono internamente la porta 22, il ruolo li mappa su porte host differenti e predefinite (es. 2201 per Ubuntu, 2202 per Alpine), rendendoli accessibili simultaneamente.

# STEP 4 - Vault

L'introduzione di Ansible Vault ha permesso di elevare il livello di sicurezza del progetto, eliminando la pratica insicura di inserire password in chiaro nei file di configurazione o nei Dockerfile.

## Meccanismo di Sicurezza

    - Secrets Management: Le password sensibili sono archiviate nel file secrets.yml, cifrato con AES-256.

    - Build-Time Injection: Durante la generazione dei Dockerfile, Ansible decifra le variabili in memoria, calcola l'hash sicuro (SHA-512) della password e inietta direttamente l'hash nel comando useradd o usermod. In questo modo, il Dockerfile finale e l'immagine risultante non contengono mai la password in chiaro, ma solo il suo hash.

Per eseguire il playbook decifrando i segreti al volo:

ansible-playbook --ask-vault-pass site.yml


# STEP 5 - Jenkins & Ansible

L'ultimo step ha introdotto un server di automazione Jenkins, configurato non come semplice esecutore, ma come un nodo operativo ("Ops Node") containerizzato con capacità di controllo sul Docker Host.

## Architettura "Docker-outside-of-Docker"

Il container Jenkins è stato personalizzato (my-jenkins-ops) per includere il client Docker. Montando il socket Docker dell'host (/var/run/docker.sock) all'interno del container, Jenkins è in grado di lanciare comandi che vengono eseguiti effettivamente dal motore Docker della macchina ospite.

## La Pipeline

La logica di deployment è definita in una Pipeline Dichiarativa (il cui codice è disponibile nel file separato pipeline_jenkins.groovy o configurato direttamente su Jenkins).

## Logica della Pipeline:

    - Build & Push: Genera una nuova versione dell'applicazione (basata su Alpine), la tagga con il numero progressivo della build di Jenkins e la carica sul registry locale.

    - Deploy Automatico: Scarica l'immagine appena creata e sostituisce il container in esecuzione con la nuova versione, garantendo un aggiornamento continuo.
