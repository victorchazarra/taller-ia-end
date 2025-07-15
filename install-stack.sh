#!/bin/bash

echo "🚀 Instalando Stack Completo: N8n + Docker + Portainer + Evolution API + Supabase"
echo "================================================================================"

# Obtener IP pública
PUBLIC_IP=$(curl -s ifconfig.me)
echo "📍 IP detectada: $PUBLIC_IP"

# Actualizar sistema
echo "📦 Actualizando sistema..."
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y

# Instalar dependencias básicas
echo "🔧 Instalando dependencias..."
apt install -y curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release

# Instalar Node.js (necesario para N8n)
echo "📦 Instalando Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Instalar N8n globalmente
echo "🤖 Instalando N8n..."
npm install -g n8n

# Crear servicio systemd para N8n
echo "⚙️ Configurando servicio N8n..."
cat > /etc/systemd/system/n8n.service << 'EOF'
[Unit]
Description=n8n workflow automation
After=network.target

[Service]
Type=simple
User=root
Environment=N8N_BASIC_AUTH_ACTIVE=false
Environment=N8N_HOST=0.0.0.0
Environment=N8N_PORT=5678
Environment=N8N_PROTOCOL=http
Environment=WEBHOOK_URL=http://PUBLIC_IP_PLACEHOLDER:5678/
ExecStart=/usr/bin/n8n start
Restart=on-failure
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=n8n

[Install]
WantedBy=multi-user.target
EOF

# Reemplazar placeholder con IP real
sed -i "s/PUBLIC_IP_PLACEHOLDER/$PUBLIC_IP/g" /etc/systemd/system/n8n.service

# Habilitar y iniciar N8n
systemctl daemon-reload
systemctl enable n8n
systemctl start n8n

# Instalar Docker
echo "🐳 Instalando Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl start docker
systemctl enable docker

# Instalar Docker Compose
echo "🔧 Instalando Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Crear directorio para el stack
echo "📁 Creando estructura de archivos..."
mkdir -p /opt/ai-stack
cd /opt/ai-stack

# Crear docker-compose.yml completo
echo "📝 Creando configuración Docker Compose..."
cat > docker-compose.yml << EOF
version: '3.8'

services:
  # Portainer para gestión visual
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    restart: unless-stopped

  # Evolution API
  evolution-api:
    image: atendai/evolution-api:latest
    container_name: evolution-api
    ports:
      - "8082:8080"
    environment:
      - SERVER_URL=http://$PUBLIC_IP:8082
      - CORS_ORIGIN=*
      - CORS_CREDENTIALS=true
      - DEL_INSTANCE=false
      - DATABASE_ENABLED=true
      - DATABASE_CONNECTION_URI=postgresql://evolution:evolution@postgres:5432/evolution
      - REDIS_ENABLED=true
      - REDIS_URI=redis://redis:6379
      - AUTHENTICATION_API_KEY=evolution-api-key-123
      - WEBHOOK_URL=http://$PUBLIC_IP:8082/webhook
    depends_on:
      - postgres
      - redis
    volumes:
      - evolution_instances:/evolution/instances
      - evolution_store:/evolution/store
    restart: unless-stopped

  # PostgreSQL para Evolution API
  postgres:
    image: postgres:15
    container_name: evolution-postgres
    environment:
      - POSTGRES_DB=evolution
      - POSTGRES_USER=evolution
      - POSTGRES_PASSWORD=evolution123
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    ports:
      - "5432:5432"

  # Redis para Evolution API
  redis:
    image: redis:7-alpine
    container_name: evolution-redis
    volumes:
      - redis_data:/data
    restart: unless-stopped
    ports:
      - "6379:6379"

  # Redis independiente para uso general
  redis-general:
    image: redis:7-alpine
    container_name: redis-general
    command: redis-server --appendonly yes --requirepass redis123
    volumes:
      - redis_general_data:/data
    ports:
      - "6380:6379"
    restart: unless-stopped

  # Redis Commander - Interfaz web para gestionar Redis
  redis-commander:
    image: rediscommander/redis-commander:latest
    container_name: redis-commander
    environment:
      - REDIS_HOSTS=evolution:evolution-redis:6379,general:redis-general:6379:0:redis123
      - HTTP_USER=admin
      - HTTP_PASSWORD=redis123
    ports:
      - "8083:8081"
    depends_on:
      - redis
      - redis-general
    restart: unless-stopped

  # Supabase Database
  supabase-db:
    image: supabase/postgres:15.1.0.117
    container_name: supabase-db
    environment:
      - POSTGRES_PASSWORD=supabase123
      - POSTGRES_DB=postgres
      - POSTGRES_USER=postgres
    volumes:
      - supabase_db:/var/lib/postgresql/data
    ports:
      - "5433:5432"
    restart: unless-stopped

  # Supabase Auth
  supabase-auth:
    image: supabase/gotrue:v2.99.0
    container_name: supabase-auth
    environment:
      - GOTRUE_API_HOST=0.0.0.0
      - GOTRUE_API_PORT=9999
      - GOTRUE_DB_DRIVER=postgres
      - GOTRUE_DB_DATABASE_URL=postgres://postgres:supabase123@supabase-db:5432/postgres?search_path=auth
      - GOTRUE_SITE_URL=http://$PUBLIC_IP:3000
      - GOTRUE_URI_ALLOW_LIST=http://$PUBLIC_IP:3000
      - GOTRUE_JWT_SECRET=super-secret-jwt-token-with-at-least-32-characters-long
      - GOTRUE_JWT_EXP=3600
      - GOTRUE_JWT_DEFAULT_GROUP_NAME=authenticated
    depends_on:
      - supabase-db
    restart: unless-stopped

  # Supabase REST API
  supabase-rest:
    image: postgrest/postgrest:v10.1.1
    container_name: supabase-rest
    environment:
      - PGRST_DB_URI=postgres://postgres:supabase123@supabase-db:5432/postgres
      - PGRST_DB_SCHEMAS=public
      - PGRST_DB_ANON_ROLE=anon
      - PGRST_JWT_SECRET=super-secret-jwt-token-with-at-least-32-characters-long
    depends_on:
      - supabase-db
    restart: unless-stopped

  # Supabase Studio
  supabase-studio:
    image: supabase/studio:20231123-a0ce425
    container_name: supabase-studio
    environment:
      - SUPABASE_URL=http://$PUBLIC_IP:8001
      - SUPABASE_REST_URL=http://supabase-rest:3000
      - SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
      - SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU
    ports:
      - "3000:3000"
    depends_on:
      - supabase-db
    restart: unless-stopped

  # Kong API Gateway para Supabase
  supabase-kong:
    image: kong:2.8.1
    container_name: supabase-kong
    environment:
      - KONG_DATABASE=off
      - KONG_DECLARATIVE_CONFIG=/var/lib/kong/kong.yml
      - KONG_DNS_ORDER=LAST,A,CNAME
      - KONG_PLUGINS=request-size-limiting,cors,key-auth,acl,basic-auth
      - KONG_NGINX_PROXY_PROXY_BUFFER_SIZE=160k
      - KONG_NGINX_PROXY_PROXY_BUFFERS=64 160k
    ports:
      - "8001:8000"
    volumes:
      - ./kong.yml:/var/lib/kong/kong.yml:ro
    depends_on:
      - supabase-auth
      - supabase-rest
    restart: unless-stopped

volumes:
  portainer_data:
  evolution_instances:
  evolution_store:
  postgres_data:
  redis_data:
  redis_general_data:
  supabase_db:
EOF

# Crear configuración de Kong para Supabase
echo "🔧 Configurando Kong Gateway..."
cat > kong.yml << 'EOF'
_format_version: "1.1"

services:
  - name: auth-v1-open
    url: http://supabase-auth:9999
    routes:
      - name: auth-v1-open
        strip_path: true
        paths:
          - /auth/v1
    plugins:
      - name: cors
        config:
          origins:
            - "*"
          methods:
            - GET
            - POST
            - PUT
            - PATCH
            - DELETE
            - OPTIONS
          headers:
            - Accept
            - Accept-Language
            - Authorization
            - Content-Type
            - X-Requested-With

  - name: rest-v1
    url: http://supabase-rest:3000
    routes:
      - name: rest-v1
        strip_path: true
        paths:
          - /rest/v1
    plugins:
      - name: cors
        config:
          origins:
            - "*"
          methods:
            - GET
            - POST
            - PUT
            - PATCH
            - DELETE
            - OPTIONS
          headers:
            - Accept
            - Accept-Language
            - Authorization
            - Content-Type
            - X-Requested-With
EOF

# Configurar firewall
echo "🔥 Configurando firewall..."
ufw allow 22/tcp
ufw allow 5678/tcp
ufw allow 9000/tcp
ufw allow 8082/tcp
ufw allow 3000/tcp
ufw allow 8001/tcp
ufw allow 8083/tcp
ufw allow 6379/tcp
ufw allow 6380/tcp
echo "y" | ufw enable

# Iniciar servicios Docker
echo "🎯 Iniciando servicios Docker..."
docker-compose up -d

# Esperar a que los servicios se inicien
echo "⏳ Esperando que los servicios se inicien..."
sleep 60

# Verificar estado de servicios
echo "🔍 Verificando servicios..."
echo "N8n status:"
systemctl status n8n --no-pager -l
echo ""
echo "Docker containers:"
docker ps

# Mostrar información de acceso
echo ""
echo "🎉 ¡INSTALACIÓN COMPLETADA!"
echo "================================================================================"
echo "🤖 N8n: http://$PUBLIC_IP:5678"
echo "📊 Portainer (Gestión Docker): http://$PUBLIC_IP:9000"
echo "📱 Evolution API: http://$PUBLIC_IP:8082"
echo "🗄️ Supabase Studio: http://$PUBLIC_IP:3000"
echo "🌐 Supabase API Gateway: http://$PUBLIC_IP:8001"
echo "🔴 Redis Commander: http://$PUBLIC_IP:8083"
echo ""
echo "🔑 Credenciales importantes:"
echo "- Evolution API Key: evolution-api-key-123"
echo "- Supabase DB Password: supabase123"
echo "- Evolution DB Password: evolution123"
echo "- Redis General Password: redis123"
echo "- Redis Commander User: admin / Password: redis123"
echo ""
echo "🔴 Puertos Redis:"
echo "- Redis Evolution API: puerto 6379 (sin password)"
echo "- Redis General: puerto 6380 (password: redis123)"
echo ""
echo "📁 Archivos de configuración en: /opt/ai-stack"
echo "📝 Para gestionar servicios Docker: usar Portainer en puerto 9000"
echo "📋 Para ver logs de N8n: journalctl -u n8n -f"
echo "================================================================================"
echo ""
echo "🚀 ¡Todo listo! Puedes empezar a usar tu stack completo de IA!"
EOF
