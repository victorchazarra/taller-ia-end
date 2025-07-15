#!/bin/bash

echo "🚀 Instalando Stack Completo: Docker + Portainer + Evolution API + Supabase"
echo "=================================================================="

# Actualizar sistema
echo "📦 Actualizando sistema..."
apt update && apt upgrade -y

# Instalar Docker
echo "🐳 Instalando Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl start docker
systemctl enable docker

# Instalar Docker Compose
echo "🔧 Instalando Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Crear directorio para el stack
echo "📁 Creando estructura de archivos..."
mkdir -p /opt/ai-stack
cd /opt/ai-stack

# Crear docker-compose.yml completo
cat > docker-compose.yml << 'EOF'
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
      - SERVER_URL=http://$(curl -s ifconfig.me):8082
      - CORS_ORIGIN=*
      - CORS_CREDENTIALS=true
      - DEL_INSTANCE=false
      - DATABASE_ENABLED=true
      - DATABASE_CONNECTION_URI=postgresql://evolution:evolution@postgres:5432/evolution
      - REDIS_ENABLED=true
      - REDIS_URI=redis://redis:6379
      - AUTHENTICATION_API_KEY=evolution-api-key-123
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
      - POSTGRES_PASSWORD=evolution
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  # Redis para Evolution API
  redis:
    image: redis:7-alpine
    container_name: evolution-redis
    volumes:
      - redis_data:/data
    restart: unless-stopped

  # Supabase Stack
  supabase-db:
    image: supabase/postgres:15.1.0.147
    container_name: supabase-db
    environment:
      - POSTGRES_PASSWORD=your-super-secret-and-long-postgres-password
      - POSTGRES_DB=postgres
    volumes:
      - supabase_db:/var/lib/postgresql/data
    restart: unless-stopped

  supabase-studio:
    image: supabase/studio:20240101-ce42139
    container_name: supabase-studio
    environment:
      - SUPABASE_URL=http://supabase-kong:8000
      - SUPABASE_REST_URL=http://supabase-kong:8000/rest/v1/
      - SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
      - SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU
    ports:
      - "3000:3000"
    depends_on:
      - supabase-db
    restart: unless-stopped

  supabase-kong:
    image: kong:2.8.1
    container_name: supabase-kong
    environment:
      - KONG_DATABASE=off
      - KONG_DECLARATIVE_CONFIG=/var/lib/kong/kong.yml
      - KONG_DNS_ORDER=LAST,A,CNAME
      - KONG_PLUGINS=request-size-limiting,cors,key-auth,acl,basic-auth
    ports:
      - "8000:8000"
    volumes:
      - ./kong.yml:/var/lib/kong/kong.yml:ro
    depends_on:
      - supabase-db
    restart: unless-stopped

volumes:
  portainer_data:
  evolution_instances:
  evolution_store:
  postgres_data:
  redis_data:
  supabase_db:
EOF

# Crear configuración de Kong para Supabase
cat > kong.yml << 'EOF'
_format_version: "1.1"

services:
  - name: auth-v1-open
    url: http://supabase-auth:9999/verify
    routes:
      - name: auth-v1-open
        strip_path: true
        paths:
          - /auth/v1/verify
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

# Obtener IP pública
PUBLIC_IP=$(curl -s ifconfig.me)

# Iniciar servicios
echo "🎯 Iniciando servicios..."
docker-compose up -d

# Esperar a que los servicios se inicien
echo "⏳ Esperando que los servicios se inicien..."
sleep 30

# Mostrar información de acceso
echo ""
echo "🎉 ¡INSTALACIÓN COMPLETADA!"
echo "=================================================================="
echo "📊 Portainer (Gestión Docker): http://$PUBLIC_IP:9000"
echo "📱 Evolution API: http://$PUBLIC_IP:8082"
echo "🗄️  Supabase Studio: http://$PUBLIC_IP:3000"
echo "🤖 N8n: http://$PUBLIC_IP:5678 (ya instalado)"
echo ""
echo "🔑 Credenciales:"
echo "- Evolution API Key: evolution-api-key-123"
echo "- Supabase DB Password: your-super-secret-and-long-postgres-password"
echo ""
echo "📝 Archivos de configuración en: /opt/ai-stack"
echo "=================================================================="
EOF
