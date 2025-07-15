#!/bin/bash

echo "🚀 Instalando Stack Básico - 100% Funcional para Alumnos"
echo "======================================================="

# Obtener IP pública
PUBLIC_IP=$(curl -s ifconfig.me)
echo "📍 IP detectada: $PUBLIC_IP"

# Actualizar sistema (sin interrupciones)
echo "📦 Actualizando sistema..."
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y

# Instalar dependencias básicas
echo "🔧 Instalando dependencias básicas..."
apt install -y curl wget git unzip software-properties-common

# Instalar Node.js para N8n
echo "📦 Instalando Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Instalar N8n
echo "🤖 Instalando N8n..."
npm install -g n8n

# Crear servicio N8n simple
echo "⚙️ Configurando N8n como servicio..."
cat > /etc/systemd/system/n8n.service << EOF
[Unit]
Description=n8n workflow automation
After=network.target

[Service]
Type=simple
User=root
Environment=N8N_HOST=0.0.0.0
Environment=N8N_PORT=5678
Environment=N8N_PROTOCOL=http
Environment=WEBHOOK_URL=http://$PUBLIC_IP:5678/
ExecStart=/usr/bin/n8n start
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Iniciar N8n
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

# Instalar Portainer
echo "📊 Instalando Portainer..."
docker run -d \
  --name portainer \
  --restart=always \
  -p 9000:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

# Configurar firewall básico
echo "🔥 Configurando firewall..."
ufw allow 22/tcp
ufw allow 5678/tcp
ufw allow 9000/tcp
echo "y" | ufw enable

# Crear directorio para stacks
echo "📁 Creando directorio de trabajo..."
mkdir -p /opt/docker-stacks
cd /opt/docker-stacks

# Esperar a que Portainer esté listo
echo "⏳ Esperando que Portainer se inicie..."
sleep 30

# Verificar servicios
echo "🔍 Verificando instalación..."
echo ""
echo "N8n status:"
systemctl status n8n --no-pager -l | head -5
echo ""
echo "Docker status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🎉 ¡INSTALACIÓN BÁSICA COMPLETADA!"
echo "=================================="
echo ""
echo "🔗 ACCESOS:"
echo "🤖 N8n: http://$PUBLIC_IP:5678"
echo "📊 Portainer: http://$PUBLIC_IP:9000"
echo ""
echo "📝 PRÓXIMOS PASOS:"
echo "1. Accede a Portainer: http://$PUBLIC_IP:9000"
echo "2. Crea tu usuario administrador"
echo "3. Ve a 'Stacks' para instalar más servicios"
echo ""
echo "🎯 TODO LISTO PARA CONTINUAR CON LA INSTALACIÓN VISUAL"
echo "=================================="
