
En construcción ...
## Instalación en desarrollo

### Consideraciones previas

Disponemos de un servidor VPS con las siguientes caracteristicas:
```bash
free -h
					total      
	Mem:           8.0Gi
	Swap:          4.0Gi
```
```bash
lscpu | grep -E "Architecture|CPU\(s\)|Thread|Core|Socket|Virtualization"
	Architecture:                         x86_64
	CPU(s):                               40
	On-line CPU(s) list:                  14,18,38
	Off-line CPU(s) list:                 0-13,15-17,19-37,39
	Thread(s) per core:                   2
	Core(s) per socket:                   10
	Socket(s):                            2
	CPU(s) scaling MHz:                   83%
	Virtualization:                       VT-x
	NUMA node0 CPU(s):                    0-9,20-29
	NUMA node1 CPU(s):                    10-19,30-39
```
```bash
df -h --total | grep -E "Filesystem|total"
	Filesystem                           Size  Used Avail Use% Mounted on
	total                                126G  1.1G  124G   1% -
```
```bash
uname -a
    Linux 5.15.158-2-pve #1 SMP PVE 5.15.158-2 (2024-07-26T13:11Z) x86_64 x86_64 x86_64 GNU/Linux
```
```bash
lsb_release -a
	Distributor ID:	Ubuntu
	Description:	Ubuntu 24.04.4 LTS
	Release:	24.04
	Codename:	noble
```
- Ya se dispone de un dominio apuntando al servidor
- Se creó el usuario decidim
- Directorio de la aplicación para desarrollo: /home/decidim/fsmac_decidim
- Generación de SECRET_KEY_BASE con

```bash
cd ~/fsmac_decidim
DISABLE_SPRING=1 bin/rails secret
```
- El acceso al servidor se realiza mediante SSH con claves impidiendo acceso root y configurando:

```bash
sudo nano /etc/ssh/sshd_config

	PermitRootLogin no
	PasswordAuthentication no
	PubkeyAuthentication yes
	MaxAuthTries 3
```

- Decidim fue instalado para desarrollo con las instrucciones mencionadas en https://docs.decidim.org/en/develop/install/manual con las siguientes particularidades:
    - No fue ejecutado bin/rails db:seed para no cargar la organización de ejemplo.
	- Se incluyó en el Gemfile la Gemas:
	   - gem "decidim-decidim_awesome"
       - gem "decidim-extra_user_fields", github: "openpoke/decidim-module-extra_user_fields"
       - gem "decidim-term_customizer", github: "openpoke/decidim-module-term_customizer"
	   - Antes de crear y migrar la base de datos, el cluster de la base de datos fue creado con:
	   	```bash
		sudo locale-gen es_ES.UTF-8
        sudo update-locale
		sudo pg_createcluster 16 main --start -- --encoding=UTF8 --locale=es_ES.UTF-8
		```
		después:

		```bash
		bin/rails db:create db:migrate
		```
- Archivo para secrets: **`~/.rbenv-vars`** Su contenido tras sucesivas inclusiones de variables de entorno a lo largo del proceso de paso a producción es el siguiente:

	```bash
	DATABASE_HOST=127.0.0.1
	DATABASE_NAME=fsmac_decidim_production
	DATABASE_USERNAME=decidim_app
	DATABASE_PASSWORD=<db_password>
	DATABASE_PORT=5432

	# Entorno
	RAILS_ENV=production
	SECRET_KEY_BASE=<secret_key_base>

	# Puma
	# Cuando se crezca en usuarios puede subirse `WEB_CONCURRENCY` a 6-8 sin problema con 0.0 Gi RAM disponibles
	WEB_CONCURRENCY=4
	RAILS_MAX_THREADS=3

	# Redis
	REDIS_URL=redis://127.0.0.1:6379/0

	# SMTP
	##############################################################
	# OJO: En caso de modificar algun valor de este apartado SMTP
	#      Ejecuta [~/bin/generate_msmtprc.sh]
	#      Para actualizar msmtprc.sh con los valores actualizados
	##############################################################
	SMTP_USERNAME=no-reply@forosocial.org
	SMTP_PASSWORD=<smtp_password>
	SMTP_ADDRESS=<smtp_address>
	SMTP_TLS=true
	SMTP_PORT=465
	SMTP_DOMAIN=forosocial.org
	SMTP_FROM_EMAIL=no-reply@forosocial.org
	SMTP_FROM_LABEL=Foro Social Más Allá del Crecimiento

	# App
	PORT=3000
	RAILS_SERVE_STATIC_FILES=true
	RAILS_LOG_TO_STDOUT=true

	# exception_notifications
	EXCEPTION_RECIPIENTS=dev@forosocial.org,webmaster@forosocial.org

	```
	Más tarde se comentarán las lineas y aspectos de este archivo

---

## Instalación para producción

### Guia de implementación
Se ha tomado como referencia y guia para la implementación de la instancia en desarrollo se ha seguido el [Check list publicado en la documentación de Decidim](https://docs.decidim.org/en/develop/install/checklist)

---

### Inicializador para Decidim
La instalación manual de Decidim no crea un inicializador por defecto, necesitamos crearlo como `~/fsmac_decidim/config/initializrs/decidim.rb`. Su contenido está [aquí](https://github.com/forosocial/decidim/blob/main/config/initializers/decidim.rb)

---

### Active Storage

Por defecto Decidim usa el disco local (`local`), lo que significa que los archivos se guardan en `storage/` del servidor.
Su configuración se configura en [`~/fsmac_decidim/config/storage.yml`](https://github.com/forosocial/decidim/blob/main/config/storage.yml)

Podemos configurar en [config/environments/production.rb](https://github.com/forosocial/decidim/blob/main/config/environments/production.rb)
que la variable opcional `STORAGE_PROVIDER` está preparada para, cuando se desee definirla en `~/.rbenv-vars`:
```ruby
# config/environments/production.rb
...
config.active_storage.service = Decidim::Env.new("STORAGE_PROVIDER", "local").to_s
...

```
El tamaño de los archivos subidos por los usuarios lo tenemos limitado en el inicializador [decidim.rb](https://github.com/forosocial/decidim/blob/main/config/initializers/decidim.rb):

```ruby
config.maximum_attachment_size = 10  # MB por archivo adjunto
config.maximum_avatar_size = 5       # MB para avatares
```
---


### Instalación y configuración inicial del servidor web Nginx:

Nginx gestiona SSL, archivos estáticos y conexiones

```bash
sudo apt install nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```
Verifiqué que funciona visitando `http://decidim.forosocial.org` — mostrando la página por defecto de Nginx.

Creé una configuración básica

```bash
sudo nano /etc/nginx/sites-available/decidim
```
que tras modificaciones posteriores quedó así:

```nginx
server {
    listen 80;
    server_name decidim.forosocial.org;

	# Certbot sirve el challenge directamente desde el sistema de archivos
	location /.well-known/acme-challenge/ {
        root /var/www/html;
	}

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```
posteriormente iremos modificando la configuración. Ahora verificamos funcionamiento sin errores:

```bash
sudo ln -s /etc/nginx/sites-available/decidim /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```
---

### Instalación y configuración de Certbot

```bash
sudo apt install certbot python3-certbot-nginx
```
Ahora Certbot se encarga automáticamente de añadir a /etc/nginx/sites-available/decidim el bloque SSL, el certificado y la redirección HTTP → HTTPS, pidiendo email para notificaciones de renovación y que acepte los términos de uso.

```bash
sudo certbot --nginx -d http://decidim.forosocial.org
```

Si posteriormente quiero cambiar el email puedo:
```bash
	sudo certbot update_account --email nuevo@email.com
```
Podemos ver como Certbot ha modificado /etc/nginx/sites-available/decidim.
Ahora reniciamos nginx como antes hicimos

---

### Instalación del servidor de aplicación Puma

Puma ejecuta la aplicación (el código Ruby/Rails) y atiende las peticiones que le llegan de Nginx, además:
- Gestionará **múltiples workers y threads** para atender peticiones concurrentes
- Arranca en modo optimizado **sin recargas** de desarrollo (bin/dev)
- Arranca automáticamente con el sistema y se reinicia si cae

Editamos su archivo de configuración
```bash
	nano ~/fsmac_decidim/config/puma.rb
```
Incluimos el siguente contenido: ([puma.rb](https://github.com/forosocial/decidim/blob/main/config/puma.rb))

---

### Instalación y configuración de Redis

Redis es una base de datos en memoria de alto rendimiento que gestiona tareas que requieren velocidad, como:
- Almacenamiento en caché para almacenamiento de la app
- Backend para tareas almacenamiento en segundo plano de tareas en cola como envío de emails. Los trabajadores (workers)de sidekiq las ejecutan en segundo plano, y Redis persiste los datos para que no se pierdan incluso si el sistema se reinicia
- Tareas en tiempo real (chats en vivo, notificaciones o actualizaciones en tiempo real con Action Cable)

```bash
	sudo apt install redis-server
	sudo systemctl enable redis-server
	sudo systemctl start redis-server
```

Verificamos que funciona:

```bash
	redis-cli ping
	# Debe responder: PONG
```
---

### Instalación y configuración de Sidekiq

Sidekiq tiene un panel web en `/sidekiq` para monitorizar colas y trabajos fallidos.
Decidim usa bastantes jobs en producción (emails, notificaciones, exportaciones...) y Sidekiq los gestiona

Añadimos al `Gemfile` de la app:

```bash
	nano ~/fsmac_decidim/Gemfile
```

Añadimos estas líneas:

```ruby
	gem "sidekiq"
	gem "redis"
```

Instalamos:

```bash
	cd ~/fsmac_decidim
	bundle install
```

---

Creamos el inicializador  ([config/initializers/sidekiq.rb](https://github.com/forosocial/decidim/blob/main/config/initializers/sidekiq.rb)) y configuramos ActiveJob para usar Sidekiq en [`config/application.rb`](https://github.com/forosocial/decidim/blob/main/config/application.rb), incluyendo dentro de la clase `Application` la línea config.active_job.queue_adapter = :sidekiq



---

Creamos el Servicio systemd para Sidekiq con la siguiente configuración:

```bash
	# /etc/systemd/system/sidekiq.service

	[Unit]
	Description=Sidekiq (Decidim)
	After=network.target postgresql.service redis.service

	[Service]
	Type=simple
	User=decidim
	WorkingDirectory=/home/decidim/fsmac_decidim
	ExecStart=/home/decidim/.rbenv/bin/rbenv exec bundle exec sidekiq
	Restart=on-failure
	RestartSec=5
	EnvironmentFile=/home/decidim/.rbenv-vars

	[Install]
	WantedBy=multi-user.target
```
---
### Gestión de cache
Por defecto Rails usa una configuración de cache en archivos temporales, mover la caché de Rails de FileStore a RedisCacheStore, evita la posibilidad de choques de escritura competitiva cuando se usa con un servidor multihilo como Puma. Como usamos la base de datos 0 de Redis para tareas sidekiq, ahora usaremos otra nueva separada para la gestión de la caché `redis://127.0.0.1:6379/1`
La configuración la hacemos en [config/environments/production.rb](https://github.com/forosocial/decidim/blob/main/config/environments/production.rb)

```ruby
config.cache_store = :redis_cache_store, {
    url: ENV.fetch("REDIS_CACHE_URL", "redis://127.0.0.1:6379/1"),
    namespace: "fsmac_decidim_cache",
    connect_timeout: 1,    # segundos para intentar conectar
    read_timeout: 0.5,
    write_timeout: 0.5,
    reconnect_attempts: 1,
    error_handler: ->(method:, returning:, exception:) {
        Rails.logger.warn(
            "[RedisCacheStore] Error en #{method}: #{exception.class} #{exception.message}. " \
            "Devolviendo #{returning.inspect}"
        )
    }
  }
```
Podemos comprobar el funcionamiento correcto de la caché de redis:

```bash
redis-cli -n 1 keys "fsmac_decidim_cache*" | head -5

```

---

### Creación de la base de datos de producción

Inicialmente incluimos en [config/database.yml](https://github.com/forosocial/decidim/blob/main/config/database.yml) la denominación de la base de datso de producción. En nuestro caso: 
	
	production:
  		<<: *default
  		database: fsmac_decidim_production
	
Después creamos la base de datos de producción y el administrador de la misma
	
	cd ~/fsmac_decidim
	DISABLE_SPRING=1 bin/rails db:create db:migrate decidim_system:create_admin

---

### Configuración de aspectos de seguridad

Antes de exponer el servidor a internet. El puerto 3000 (Puma) no debe ser accesible directamente desde internet — solo desde Nginx internamente. Con reglas en el firewall, queda bloqueado.

Realizamos las siguientes configuraciones:

#### UFW (Firewall)

Sólo abrir los puertos estrictamente necesarios:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp      # SSH coincidente con /etc/ssh/sshd_config
sudo ufw allow 6543/tcp    # SSH coincidente con /etc/ssh/sshd_config
sudo ufw allow 45983/tcp   # SSH coincidente con /etc/ssh/sshd_config
sudo ufw allow 80/tcp      # HTTP (para redirección a HTTPS)
sudo ufw allow 443/tcp     # HTTPS
sudo ufw show added
sudo ufw enable
sudo ufw status verbose
```

#### Fail2ban — protección contra ataques de fuerza bruta

```bash
sudo apt install fail2ban
```

Creamos una configuración local:

```bash
sudo nano /etc/fail2ban/jail.local


	[DEFAULT]
	# Tiempo de baneo por defecto: 1 hora
	bantime = 3600
	# Ventana de tiempo para contar fallos
	findtime = 600
	# Número de fallos antes de banear
	maxretry = 5
	# IP de nuestra máquina de administración - No nos baneamos a nosotros mismos
	# provisionalmente añado mi IP actual de Montoro
	ignoreip = 127.0.0.1/8 ::1 85.52.81.132
	# Backend para leer logs
	backend = auto

	# -------------------------------------------------------
	# SSH
	# -------------------------------------------------------
	[sshd]
	enabled = true
	port = 22,6543,45983
	logpath = /var/log/auth.log
	maxretry = 3
	bantime  = 86400

	# -------------------------------------------------------
	# Nginx auth básica fallida
	# -------------------------------------------------------
	[nginx-http-auth]
	enabled = true
	logpath = /var/log/nginx/error.log

	# -------------------------------------------------------
	# Nginx rate limit del error.log
	# -------------------------------------------------------
	[nginx-limit-req]
	enabled = true
	logpath = /var/log/nginx/error.log
	maxretry = 10
	bantime  = 3600

	# -------------------------------------------------------
	# Bots bloqueados por User-Agent (444)
	# Lee el log separado de bots, no el access.log general
	# Agresivo: 3 intentos en 5 min → 24h de baneo
	# -------------------------------------------------------
	[nginx-bad-bots]
	enabled  = true
	filter   = nginx-bad-bots
	logpath  = /var/log/nginx/decidim_blocked_bots.log
	maxretry = 3
	findtime = 300
	bantime  = 86400

	# -------------------------------------------------------
	# Rate limit disparado en access.log (429)
	# -------------------------------------------------------
	[nginx-rate-limit]
	enabled  = true
	filter   = nginx-rate-limit
	logpath  = /var/log/nginx/decidim_access.log
	backend  = polling
	maxretry = 10
	findtime = 60
	bantime  = 3600

	# -------------------------------------------------------
	# Escaneo de rutas sensibles
	# 3 intentos en 1 min → 7 días de baneo
	# -------------------------------------------------------
	[nginx-decidim-scan]
	enabled  = true
	filter   = nginx-decidim-scan
	logpath  = /var/log/nginx/decidim_access.log
	backend  = polling
	maxretry = 3
	findtime = 60
	bantime  = 604800

	# -------------------------------------------------------
	# Ataques web — path traversal, inyecciones, exploits
	# 1 solo intento → 30 días de baneo
	# -------------------------------------------------------
	[nginx-web-attacks]
	enabled  = true
	filter   = nginx-web-attacks
	logpath  = /var/log/nginx/decidim_blocked_bots.log
	backend  = polling
	maxretry = 1
	findtime = 60
	bantime  = 2592000
```

Activamos, iniciamos y probamos:

```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
sudo fail2ban-client status
```

En caso de cambiar el contenido de este archivo, para que tenga efecto el cambio, ejecutamos:

```bash
sudo fail2ban-client reload
```

#### Actualizaciones automáticas de seguridad

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

#### CAA (Certification Authority Authorization)
Es un registro DNS que indica qué autoridades de certificación (CAs) están autorizadas a emitir certificados SSL para nuestro dominio. Es una capa de seguridad adicional que evita que otras CAs puedan emitir certificados fraudulentos.
Ya usamos Let's Encrypt, por lo que el registro CAA sólo debe autorizar a Let's Encrypt.

Añadimos el registro a la configuración del sitio con los valores:
- Dominio decidim.forosocial.org
- Registro tipo: CAA
- Opciones: 0
- Tag: issue
- Value: letsencrypt.org

#### Span, DoS, Snippets
La protección automática contra spam o contenido ofensivo sin esperar a que un admin lo revise manualmente, la protección DoS y ante snippets (archivos maliciosos) fue incluida en el [inicializador decidim.rb](https://github.com/forosocial/decidim/blob/main/config/initializers/decidim.rb)

#### Bloqueo de bots
Configuramos [public/robots.txt](https://github.com/forosocial/decidim/blob/main/public/robots.txt) para añadir una regla para que todos los bots no indexen ninguna página que contenga un perfil o búsqueda.

Sin embargo, `robots.txt` es una declaración de intenciones, no una barrera técnica. Los scrapers maliciosos o los que ignoran deliberadamente el protocolo no lo respetarán. Es necesario complementar con reglas en el servidor (Nginx/fail2ban bloqueando por User-Agent) es más efectivo. 






#### SSLtest

Verificamos nuestro dominio en [SSL Test](https://www.ssllabs.com/ssltest/)
El test tarda unos 3 minutos verifica:
- Protocolos SSL/TLS soportados
- Configuración de cifrados
- Cadena de certificados
- Cabeceras de seguridad HTTP
- Vulnerabilidades conocidas

y obtenemos una nota **A- (Acceptable security, some significant issues)** que se considera buena.

### Modificación de la configuración de Nginx

`/etc/nginx/sites-available/decidim` queda:

```
server {
    server_name decidim.forosocial.org;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

    # Bloqueo de bots de IA
    if ($http_user_agent ~* "GPTBot|CCBot|anthropic-ai|Google-Extended") {
        return 403;
    }  
    
    root /home/decidim/fsmac_decidim/public;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location ^~ /decidim-packs/ {
        gzip_static on;
        expires max;
        add_header Cache-Control public;
    }

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    listen [::]:443 ssl ipv6only=on; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/decidim.forosocial.org/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/decidim.forosocial.org/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}
server {
    if ($host = decidim.forosocial.org) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    listen 80;
    listen [::]:80;
    server_name decidim.forosocial.org;
    return 404; # managed by Certbot

}

```
Comprobamos la configuración y reiniciamos:
```bash
sudo nginx -t
sudo systemctl reload nginx
```
---
### Precompilación de assets
Compilamos todo el CSS y JavaScript para producción.

	DISABLE_SPRING=1 bin/rails assets:precompile

Esto tarda varios minutos, es normal. 

### Creación de un servicio systemd para Puma

Para no escribir las claves ya existentes en `.rbenv-vars` con permisos restrictivos y no estén expuestas en el servicio hemos creado el bash [start_production](https://github.com/forosocial/decidim/blob/main/bin/start_production) y lo hemos hecho ejecutable con `chmod +x ~/fsmac_decidim/bin/start_production`
Después lo llamaremos desde el servicio systemd para Puma

El servicio lo llmamaos decidim:

```bash
sudo nano /etc/systemd/system/decidim.service
```

```ini
[Unit]
Description=Decidim (Puma)
After=network.target postgresql.service redis.service

[Service]
Type=simple
User=decidim
WorkingDirectory=/home/decidim/fsmac_decidim
ExecStart=/home/decidim/fsmac_decidim/bin/start_production
ExecStop=/bin/kill -TSTP $MAINPID
ExecReload=/bin/kill -USR1 $MAINPID
Restart=on-failure
RestartSec=5
Environment=RAILS_ENV=production
EnvironmentFile=/home/decidim/.rbenv-vars
Environment="PATH=/home/decidim/.nvm/versions/node/v18.20.8/bin:/home/decidim/.rbenv/shims:/home/decidim/.rbenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin"

[Install]
WantedBy=multi-user.target

```
Y ahora lo habilitamos, arrancamos y comprobamos su buen funcionamiento:

```bash
sudo systemctl daemon-reload
sudo systemctl enable decidim
sudo systemctl status decidim
```

Comprobamos que Puma está corriendo con los workers que hemos definido anteriormente en `.rbenv-vars`

Arrancamos también Sidekiq:

```bash
sudo systemctl start sidekiq
sudo systemctl status sidekiq
```

Y verificamos Redis:

```bash
sudo systemctl status redis-server
```

Ahora ya podemos acceder a `https://decidim.forosocial.org` desde el navegador.

---

## Funcionalidades necesarias para producción

### Configuración de sendmail para envio de informes del servidor


AQUI

### Backups
Se realizan backups internos y externos

#### Backups internos
Creamos el directorio de backups para incluir la base de datos y el contenido de storage:
	```bash
	mkdir -p ~/backups/postgresql ~/backups/storage
	chmod 700 ~/backups/postgresql ~/backups/storage
	```
#### Backups externos
Para las salvaguardias externas usamos [rclone](https://rclone.org/)

Inicialmente generamos un par de claves dedicadas SOLO para backups sin passphrase porque rclone correrá desatendido con cron.

	```bash
	sudo ssh-keygen -t ed25519 -f /home/decidim/.config/rclone/backup_key -N "" -C "rclone-backup"

	sudo chown root:root /home/decidim/.config/rclone/
	sudo chmod 750 /home/decidim/.config/rclone/
	sudo chown root:root /home/decidim/.config/rclone/backup_key
	sudo chmod 600 /home/decidim/.config/rclone/backup_key
	```
Configuramos rclone en el servidor:

	```bash
	# ~/.config/rclone/rclone.conf
	[backup-destino]
	type = sftp
	host = IP_SERVIDOR_DESTINO
	user = backupfsmac
	key_file = /home/decidim/.config/rclone/backup_key
	shell_type = none
	```
Realizamos la **configuración en el ordenador destino** de salvaguardia

1. Creamos un nuevo usuario sin privilegios

	```bash
	useradd -m -s /bin/false backupfsmac
	```
2. Creamos un directorio "jaula"
	```bash
	mkdir -p /backup-jail/backups
	chown root:root /backup-jail
	chmod 755 /backup-jail
	chown backupuser:backupuser /backup-jail/backups
	chmod 700 /backup-jail/backups
	sudo mkdir postgresql storage
	sudo chown backupfsmac:backupfsmac postgresql/ storage/
	```
3. Añadimos en /etc/ssh/sshd_config configuración para enjaular al usuario

	```bash
	Match User backupfsmac
		ChrootDirectory /backup-jail
		ForceCommand internal-sftp
		AllowTcpForwarding no
		X11Forwarding no
		PermitTunnel no
		AllowAgentForwarding no
		AuthorizedKeysFile /backup-jail/.ssh/authorized_keys
	```
	Reiniciamos servicio sshd:

	```bash
	sudo systemctl restart sshd
	```

4. Llevamos la clave pública dedicada a rclone desde el servidor origen al destino

	```bash
	mkdir -p /backup-jail/.ssh
	```

	y pegamos el contenido de /etc/rclone/backup_key.pub del servidor origen en el destino

	```bash
	echo "ssh-ed25519 AAAA..." > /backup-jail/.ssh/authorized_keys
	chown -R backupuser:backupuser /backup-jail/.ssh
	chmod 700 /backup-jail/.ssh
	chmod 600 /backup-jail/.ssh/authorized_keys
	```
Realizamos **pruebas de conexión** con rclone

	```bash
	rclone lsd backup-destino:backups
	```
---

#### Script de backups y automatización cron

Creamos un script de backup:

	```bash
	nano ~/bin/backup.sh
	```

Con el contenido:

	```bash
	#!/bin/bash
	# Cargar variables de entorno de forma segura
	while IFS='=' read -r key value; do
	[[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
	value="${value%\'}"
	value="${value#\'}"
	export "$key=$value"
	done < /home/decidim/.rbenv-vars

	DATE=$(date +%Y%m%d_%H%M%S)
	BACKUP_DIR="/home/decidim/backups"
	DB_BACKUP_DIR="$BACKUP_DIR/postgresql"
	STORAGE_BACKUP_DIR="$BACKUP_DIR/storage"
	APP_DIR="/home/decidim/capistrano_decidim/shared"
	DAYS_TO_KEEP=5

	# Backup base de datos
	PGPASSWORD="$DATABASE_PASSWORD" pg_dump -h $DATABASE_HOST -U $DATABASE_USERNAME $DATABASE_NAME | gzip > $DB_BACKUP_DIR/backup_$DATE.sql.gz

	# Backup storage
	mkdir -p $STORAGE_BACKUP_DIR
	tar -czf $STORAGE_BACKUP_DIR/storage_$DATE.tar.gz -C $APP_DIR storage 2>/dev/null || echo "No hay uploads aún"

	# Subida a almacenamiento externo
	rclone --config /home/decidim/.config/rclone/rclone.conf copy $DB_BACKUP_DIR/backup_$DATE.sql.gz $BACKUP_REMOTE/postgresql/
	rclone --config /home/decidim/.config/rclone/rclone.conf copy $STORAGE_BACKUP_DIR/storage_$DATE.tar.gz $BACKUP_REMOTE/storage/

	# Eliminar backups internos más antiguos
	find $DB_BACKUP_DIR -name "backup_*.sql.gz" -mtime +$DAYS_TO_KEEP -delete
	find $STORAGE_BACKUP_DIR -name "storage_*.tar.gz" -mtime +$DAYS_TO_KEEP -delete

	# Eliminar backups remotos más antiguos
	rclone --config /home/decidim/.config/rclone/rclone.conf delete --min-age ${DAYS_TO_KEEP}d $BACKUP_REMOTE/postgresql/
	rclone --config /home/decidim/.config/rclone/rclone.conf delete --min-age ${DAYS_TO_KEEP}d $BACKUP_REMOTE/storage/

	echo "Backup completado: $DATE"
	```

Damos permisos de ejecución:
	```bash
	chmod 700 ~/bin/backup.sh
	```
Probamos su funcionamiento:
	```bash
	~/bin/backup.sh

	ls -lh ~/backups/postgresql/
	ls -lh ~/backups/storage/

	rclone ls backup-destino:backups/postresql
	rclone ls backup-destino:backups/storage
	```
Programamos con cron — backup diario a las 3:00 AM:

    ```bash
	crontab -e
	```
Añadimos:
	```bash
	0 3 * * * /home/decidim/backups/backup.sh >> /home/decidim/backups/backup.log 2>&1
	```

Verificamos que el cron está activo con `crontab -l`

---
#### Verificciones periódicas de backups externos

Verificación del número de archivos y espacio ocupado:

	```bash
	rclone size backup-destino:backups/

		Total objects: 12 (12)
		Total size: 173.323 MiB (181742394 Byte)
	```
Verificación de los archivos en destino

	```bash
	rclone tree backup-destino:backups/

		/
		├── postgresql
		│   ├── backup_20260604_095028.sql.gz
		│   ├── backup_20260604_100800.sql.gz
		│   ├── backup_20260605_030001.sql.gz
		│   ├── backup_20260606_030001.sql.gz
		│   ├── backup_20260607_030001.sql.gz
		│   └── backup_20260608_030001.sql.gz
		└── storage
			├── storage_20260604_095028.tar.gz
			├── storage_20260604_100800.tar.gz
			├── storage_20260605_030001.tar.gz
			├── storage_20260606_030001.tar.gz
			├── storage_20260607_030001.tar.gz
			└── storage_20260608_030001.tar.gz

		2 directories, 12 files
	```

### Logs

```bash
crontab -l
```
Nginx y Rails generan logs que crecen indefinidamente.
Usaremos  [Logrotate](https://man.archlinux.org/man/extra/man-pages-es/logrotate.8.es): su función principal es la rotación, compresión, eliminación y envío de logs, evitando que crezcan sin control hasta consumir todo el espacio en disco. Ya está instalado en Ubuntu, solo hay que configurarlo.

**Logs de Nginx** — ya los gestiona automáticamente desde la instalación de Nginx, podemos verificarlo:

```bash
cat /etc/logrotate.d/nginx
```

**Logs de Rails/Decidim** — como hemos definido la variable de entorno `RAILS_LOG_TO_STDOUT=true` en `~/.rbenv-vars` los logs van a journald y systemd ya los gestiona. 

Ahora definimos unos límtes razonables:

```bash
sudo nano /etc/systemd/journald.conf
```

```bash
	SystemMaxUse=500M
	MaxRetentionSec=30day
	MaxFileSec=1week
```

```bash
sudo systemctl restart systemd-journald
```
Verificación del espacio ocupado por logs:

```bash
journalctl --disk-usage
```
Hacemos que el usuario `decidim`pertenezca al grupo `system-journal`para poder ver todos los logs sin sudo:

```bash
sudo usermod -aG systemd-journal decidim
```
para que tome efecto tenemos que reiniciar la sesión ssh
---

### Tareas programadas
Además de las ya mencionadas anteriormente y siguiendo la configuración propuesta en [la documentación de Decidim](https://docs.decidim.org/en/develop/install/) se han creado las siguientes:

```bash
crontab -l

SHELL=/bin/bash
PATH=/home/decidim/.rbenv/shims:/home/decidim/.rbenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Eliminar archivos expirados de "descarga de tus datos" (diaria a las 00:00)
# Decidim permite a los usuarios descargar todos sus datos personales (RGPD).
# Estos archivos se generan y se guardan temporalmente en el servidor. Esta tarea elimina los archivos que ya han expirado
0 0 * * * cd /home/decidim/fsmac_decidim && RAILS_ENV=production bundle exec rake decidim:delete_download_your_data_files >> /home/decidim/logs/cron.log 2>&1

# Generar open data (exportaciones públicas)  (diaria a las 00:02)
# Genera los datasets públicos de open data que Decidim publica — propuestas, reuniones, resultados, etc. en formato CSV/JSON 
# descargable por cualquier ciudadano. Es el job OpenDataJob 
2 0 * * * cd /home/decidim/fsmac_decidim && RAILS_ENV=production bundle exec rake decidim:open_data:export >> /home/decidim/logs/cron.log 2>&1

# Eliminar formularios de registro de reuniones antiguos (diaria a las 00:03)
# Elimina los formularios de registro de reuniones que ya han pasado.
# Cuando alguien se registra en una reunión rellena un formulario 
# una vez finalizada la reunión, estos datos no son necesarios y se limpian para proteger la privacidad de los participantes.
3 0 * * * cd /home/decidim/fsmac_decidim && RAILS_ENV=production bundle exec rake decidim_meetings:clean_registration_forms >> /home/decidim/logs/cron.log 2>&1

# Generar recordatorios (diaria a las 00:04)
# Envía recordatorios automáticos a los usuarios — por ejemplo,
# recordatorio de que una votación está a punto de cerrar, que una reunión se acerca,
# o que una propuesta en la que participaron está llegando a su fin.
4 0 * * * cd /home/decidim/fsmac_decidim && RAILS_ENV=production bundle exec rake decidim:reminders:all >> /home/decidim/logs/cron.log 2>&1

# Enviar digest de notificaciones diario  (diaria a las 00:05)
# Los usuarios pueden elegir recibir sus notificaciones agrupadas en un resumen diario
# en lugar de recibirlas una a una. Esta tarea envía ese email resumen a quienes eligieron la frecuencia diaria.
5 0 * * * cd /home/decidim/fsmac_decidim && RAILS_ENV=production bundle exec rake decidim:mailers:notifications_digest_daily >> /home/decidim/logs/cron.log 2>&1

# Enviar digest de notificaciones semanal (sábados a las 00:05)
# Igual que la anterior a los que eligieron un resumen semanal 
5 0 * * 6 cd /home/decidim/fsmac_decidim && RAILS_ENV=production bundle exec rake decidim:mailers:notifications_digest_weekly >> /home/decidim/logs/cron.log 2>&1

# Cambiar fase activa en procesos participativos (a las 00:06)
# Los procesos participativos tienen fases con fechas de inicio y fin. 
# Esta tarea comprueba cada día si alguna fase debe activarse o desactivarse automáticamente
# según las fechas configuradas.
6 0 * * * cd /home/decidim/fsmac_decidim && RAILS_ENV=production bundle exec rake decidim_participatory_processes:change_active_step >> /home/decidim/logs/cron.log 2>&1

# Eliminar cuentas de participantes inactivos (a las 0:00)
# Elimina automáticamente cuentas de usuarios que llevan mucho tiempo inactivos,
# según la política de retención de datos configurada en la organización. Importante para cumplir con el RGPD.
0 0 * * * cd /home/decidim/fsmac_decidim && RAILS_ENV=production bundle exec rake decidim:participants:delete_inactive_participants >> /home/decidim/logs/cron.log 2>&1

# Backup de base de datos y uploads (a las 03:00)
0 3 * * * /home/decidim/bin/backup.sh >> /home/decidim/logs/backup.log 2>&1

# Comprobar certificado SSL semanalmente
0 9 * * 1 /home/decidim/bin/check_ssl.sh >> /home/decidim/logs/cron.log 2>&1

```

---
### Monitorización

#### Notificaciones de excepciones
Los errores que se producen en producción son notificados via email.
Ppermite recibir alertas cuando Rails genera un error en producción, con toda la información del error (stack trace, usuario, URL, parámetros) evita tener que estar mirando los logs manualmente.

Se trata de una gema Ruby que hemos añadido al Gemfile:
	```ruby
	gem "exception_notification"
	```
y la instalamos con:
	```bash
	cd ~/fsmac_decidim
	bundle install
	```
posteriormente creamos el [inicializador](https://github.com/forosocial/decidim/blob/main/config/initializers/exception_notification.rb)

Posteriormente reiniciamos `decidim.service` y verificamos su funcionamiento con un email de prueba forzando un error desde la consola:

```bash
DISABLE_SPRING=1 bin/rails runner "
ExceptionNotifier.notify_exception(
  RuntimeError.new('Test de Exception Notification'),
  env: ActionDispatch::TestRequest.create,
  data: { message: 'Este es un test' }
)
"

```

Cada vez que Rails genere una excepción en producción enviará un email a la lista de correos definida como `EXCEPTION_RECIPIENTS` en `.rbenv-vars`incluyendo toda la información necesaria para diagnosticarla.

#### UptimeRobot

Es un servicio externo que hace peticiones HTTP al dominio cada 5 minutos para verificar que responde. No instala nada en el servidor ni tiene acceso a él.

Configuración de UptimeRobot con un plan gratuito que dispone de un máximo de 50 monitores, comprobación cada 5 minutos y altertas por email:

1. Creamos una cuenta gratuita en https://uptimerobot.com
2. Creamos un nuevo monitor
	- Monitor Type: **HTTP(s)**
	- Friendly Name: `Decidim Foro Social`
	- URL: `https://decidim.forosocial.org`
	- Monitoring Interval: **5 minutes**
3. Configuramos alertas por email en "Alert Contacts"
	- Añadimos emails
	- Actívamos en el monitor que acabas de crear


---

#### Sidekiq monitor

Cuando instalamos sidekiq hicimos funcional el panel web en https://decidim.forosocial/sidekiq para monitorizar colas y podemos ver estadisticas y datos actuales de las tareas procesadas, las fallidas, las ocupadas, las que están en cola, las que están siendo reintentadas, las programadas y las muertas.
Para los correos Sidekiq mostrará los `ActionMailer::MailDeliveryJob` en las distintas colas.
Tambien pueden realizarse algunas acciones. Las más importantes son:
- Eliminar: borra la tarea definitivamente, desaparece.
- Matar: mueve la tarea a la cola Muertas, donde queda guardado 6 meses por si se desea reintentarlo manualmente más tarde.
Para activarlo y montar el panel web añadimos a `config/routes.rb` lo siguiente:
	```ruby
	require "sidekiq/web"

	Rails.application.routes.draw do
	authenticate :user, ->(u) { u.admin? } do
		mount Sidekiq::Web => "/sidekiq"
	end
	# ... resto de rutas
	end
	```
Después es necesario reiniciar el servicio decidim.service


---

### Repositorio GitHub

Ya en la fase inicial y siguiento el [Manual Installation tutorial](https://docs.decidim.org/en/develop/install/manual) instalamos [git](https://git-scm.com/). Antes de realizar nuestro primer `git commit` tenemos que revisar nuestra configuración y nuestro `.gitignore`, posteriormente crearemos una cuenta en GitHub y después nuestro primer `git push`.

---

#### .gitignore
En nuestro `.gitignore`tienen que estar incluidos como mínimo los archivos sensibles o que no necesitamos en el repositorio.
Como `.rbenv-vars` está fuera del directorio de la aplicación no es necesario incluirlo.
Su contenido es el siguiente:

	```
	# Ignore bundler config.
		/.bundle

		# Ignore all environment files (except templates).
		/.env*
		!/.env*.erb

		# Ignore all logfiles and tempfiles.
		/log/*
		/tmp/*
		!/log/.keep
		!/tmp/.keep

		# Ignore pidfiles, but keep the directory.
		/tmp/pids/*
		!/tmp/pids/
		!/tmp/pids/.keep

		# Ignore storage (uploaded files in development and any SQLite databases).
		/storage/*
		!/storage/.keep
		/tmp/storage/*
		!/tmp/storage/
		!/tmp/storage/.keep

		/public/uploads
		/public/assets

		# Ignore master key for decrypting credentials and more.
		/config/master.key

		# Ignore env configuration files
		.env
		.envrc
		.rbenv-vars

		# Ignore the files and folders generated through Webpack
		/public/decidim-packs
		/public/packs-test
		/public/sw.js*

		# Ignore node modules
		/node_modules

		# Ignore Tailwind configuration
		tailwind.config.js
	```
#### Primer commit

Ejecutamos:

```
	cd ~/fsmac_decidim
	git config --global core.editor nano
	git config core.fileMode false
	git config --global user.name "forosocial"
	git config --global user.email "dev@forosocial.org"
	git status
	git add .
	git status
	git commit -m "Casi todo configurado. Sitio en servicio y protegido"
```

#### Creación de repositorio en GitHub

Vamos a `https://github.com/signup`

Introducimos:
1. Email
2. Password
3. Username: `forosocial`
4. Add .gitignore: None (Ya tenemos uno)
5. Lisence: None (Decidim usa AGPL-3.0 y ya tienes el archivo `LICENSE-AGPLv3.txt`)
6. Repository: Public
7. Verificación de cuenta
8. Verificación por email
9. Clave SSH. `Settings- SSH and GPG keys - New SSH Key` y copiamos en GitHUb la que ya tenemos en .ssh/id_ed25519.pub

Verificamos que tenemos acceso con la clave. Desde el servidor:

```
ssh -T git@github.com
```

Responde: `Hi forosocial! You've successfully authenticated, but GitHub does not provide shell access.`

#### Primer push

```
cd ~/fsmac_decidim
git remote add origin git@github.com:forosocial/decidim.git
git push -u origin main
```
### Parches y personalizaciones en la instancia de Decidim
### Seguridad en los parches
Para asegurar que las sobre escrituras del código original de Decidim no tenga afección a nuevas versiones de Decidim se han seguido las  [instrucciones de comprobación](https://docs.decidim.org/en/develop/develop/testing.html)existentes en la documentación de Decidim y en base al[script de Som Energía](https://github.com/Som-Energia/decidim-som-energia-app/blob/main/spec/lib/overrides_spec.rb) 
Para ello hemos incluido:
- la gema "rspec-rails" en el grupo developement y test de nuestro [Gemfile](https://github.com/forosocial/decidim/blob/main/Gemfile)
	Después de incluirla:
	```bash
	bundle install
    bundle exec rails generate rspec:Install
	```
	Este último genera `.rspec`, `spec/spec_helper.rb`y `spec/rails_helper.rb`

- el archivo [spec/lib/overrides_spec.rb](https://github.com/forosocial/decidim/blob/main/spec/lib/overrides_spec.rb) que hemos comentado ampliamente para su entendimiento.

En el caso de realizar actualizaciones de Decidim, siempro podemos ejecutar desde nuestro entorno de desarrollo

```bash
RAILS_ENV=test bundle exec rspec spec/lib/overrides_spec.rb
```
Que nos avisará si alguno de los archivos de decidim han cambiado a una nueva versión y, en su caso, si es necesario por nuesra parte revisar las interacciones que pueden producirse.


#### Creación de filtros por defecto
Debido a que decidim establece como filtro por defecto el Estado "Evaluating" las enmiendas se muestran en Pactos y Conflictos.
Se han realizado las siguientes modificación para excluir "Evaluating del filtro por defecto:
- Creación de [config/initializers/proposals_default_states_override.rb](https://github.com/forosocial/decidim/blob/main/config/initializers/proposals_default_states_override.rb)


