# Vultr Server Deployment Guide

## 🚀 **Vultr Server Setup**

### **Step 1: Create Vultr Instance**

**Recommended Configuration:**
- **Server Location:** Choose closest to your users (US East/West, Europe, Asia)
- **Server Type:** Cloud Compute
- **CPU:** 4 vCPUs
- **RAM:** 8GB
- **Storage:** 160GB SSD
- **OS:** Ubuntu 22.04 LTS
- **Monthly Cost:** ~$24/month

**Alternative (Budget):**
- **CPU:** 2 vCPUs
- **RAM:** 4GB
- **Storage:** 80GB SSD
- **Monthly Cost:** ~$12/month

---

## 🔧 **Server Setup Commands**

### **1. Initial Server Setup**
```bash
# SSH into your server
ssh root@YOUR_SERVER_IP

# Update system
apt update && apt upgrade -y

# Install essential packages
apt install -y curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release
```

### **2. Install Docker & Docker Compose**
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Add user to docker group
usermod -aG docker $USER
```

### **3. Install Nginx**
```bash
# Install Nginx
apt install -y nginx

# Start and enable Nginx
systemctl start nginx
systemctl enable nginx
```

### **4. Install PostgreSQL & Redis**
```bash
# Install PostgreSQL
apt install -y postgresql postgresql-contrib

# Install Redis
apt install -y redis-server

# Start services
systemctl start postgresql
systemctl enable postgresql
systemctl start redis-server
systemctl enable redis-server
```

---

## 📦 **Application Deployment**

### **1. Create Application Directory**
```bash
# Create app directory
mkdir -p /opt/zeroa-messaging
cd /opt/zeroa-messaging

# Clone your application (or create files)
git clone https://github.com/your-repo/zeroa-server.git .
```

### **2. Create Docker Compose File**
```yaml
# docker-compose.yml
version: '3.8'

services:
  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://zeroa:password@db:5432/zeroa
      - REDIS_URL=redis://redis:6379
      - TLS_API_URL=https://telestai.cryptoscope.io/api
    depends_on:
      - db
      - redis
    restart: unless-stopped

  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=zeroa
      - POSTGRES_USER=zeroa
      - POSTGRES_PASSWORD=your_secure_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```

### **3. Create Nginx Configuration**
```nginx
# /etc/nginx/sites-available/zeroa-messaging
server {
    listen 80;
    server_name your-domain.com;  # Replace with your domain

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket support for real-time messaging
    location /ws {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

### **4. Enable Site & SSL**
```bash
# Enable the site
ln -s /etc/nginx/sites-available/zeroa-messaging /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

# Test Nginx config
nginx -t

# Reload Nginx
systemctl reload nginx

# Install SSL certificate (Let's Encrypt)
apt install -y certbot python3-certbot-nginx
certbot --nginx -d your-domain.com
```

---

## 🔐 **Security Configuration**

### **1. Firewall Setup**
```bash
# Install UFW
apt install -y ufw

# Configure firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow 8000

# Enable firewall
ufw enable
```

### **2. Create Application User**
```bash
# Create non-root user
adduser zeroa
usermod -aG docker zeroa

# Switch to application user
su - zeroa
```

### **3. Environment Variables**
```bash
# Create .env file
cat > /opt/zeroa-messaging/.env << EOF
DATABASE_URL=postgresql://zeroa:your_secure_password@localhost:5432/zeroa
REDIS_URL=redis://localhost:6379
TLS_API_URL=https://telestai.cryptoscope.io/api
JWT_SECRET=your_super_secret_jwt_key
ENCRYPTION_KEY=your_32_character_encryption_key
EOF
```

---

## 🚀 **Deployment Scripts**

### **1. Quick Deploy Script**
```bash
#!/bin/bash
# deploy.sh

echo "🚀 Deploying Zeroa Messaging Server..."

# Pull latest code
git pull origin main

# Build and start services
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Run database migrations
docker-compose exec api python manage.py migrate

echo "✅ Deployment complete!"
```

### **2. Monitoring Script**
```bash
#!/bin/bash
# monitor.sh

echo "📊 Zeroa Server Status:"
echo "========================"

# Check services
echo "Docker containers:"
docker-compose ps

echo ""
echo "System resources:"
free -h
df -h

echo ""
echo "Recent logs:"
docker-compose logs --tail=20 api
```

---

## 📊 **Monitoring & Maintenance**

### **1. Log Rotation**
```bash
# Create logrotate config
cat > /etc/logrotate.d/zeroa << EOF
/opt/zeroa-messaging/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 zeroa zeroa
}
EOF
```

### **2. Backup Script**
```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup database
docker-compose exec -T db pg_dump -U zeroa zeroa > $BACKUP_DIR/db_backup_$DATE.sql

# Backup application data
tar -czf $BACKUP_DIR/app_backup_$DATE.tar.gz /opt/zeroa-messaging/data

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "✅ Backup completed: $DATE"
```

---

## 💰 **Cost Breakdown**

### **Monthly Costs:**
- **Vultr Server (4GB RAM):** $24/month
- **Domain Name:** $12/year (~$1/month)
- **SSL Certificate:** Free (Let's Encrypt)
- **Total:** ~$25/month

### **Scaling Options:**
- **8GB RAM:** $48/month (for higher traffic)
- **Load Balancer:** +$10/month (for multiple servers)
- **Managed Database:** +$15/month (optional)

---

## 🎯 **Next Steps**

1. **Order Vultr server** with specs above
2. **Run initial setup commands**
3. **Deploy application using Docker**
4. **Configure domain and SSL**
5. **Test messaging functionality**
6. **Update iOS app with server URL**

**Estimated Setup Time:** 2-3 hours
**Monthly Cost:** $25-50 depending on traffic

---

## 🔧 **Troubleshooting**

### **Common Issues:**
```bash
# Check service status
systemctl status nginx postgresql redis-server

# View logs
docker-compose logs api
journalctl -u nginx

# Restart services
docker-compose restart
systemctl restart nginx
```

### **Performance Monitoring:**
```bash
# Install monitoring tools
apt install -y htop iotop

# Monitor in real-time
htop
iotop
```

This setup gives you a production-ready messaging server on Vultr! 🚀 