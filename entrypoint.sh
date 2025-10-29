#!/bin/sh

# Get the active pool (default to blue)
ACTIVE_POOL=${ACTIVE_POOL:-blue}
PORT=${PORT:-3000}

# Determine backup pool
if [ "$ACTIVE_POOL" = "blue" ]; then
    BACKUP_POOL="green"
else
    BACKUP_POOL="blue"
fi

# Generate the nginx config
cat > /etc/nginx/conf.d/default.conf <<EOF
upstream backend {
    # Primary server based on ACTIVE_POOL
    server app_${ACTIVE_POOL}:${PORT} max_fails=1 fail_timeout=5s;
    
    # Backup server (opposite of active pool)
    server app_${BACKUP_POOL}:${PORT} backup;
}

server {
    listen 80;
    server_name localhost;

    # Aggressive timeouts for fast failover detection
    proxy_connect_timeout 2s;
    proxy_send_timeout 3s;
    proxy_read_timeout 3s;

    location / {
        proxy_pass http://backend;
        
        # CRITICAL: Retry on errors, timeouts, and 5xx within same request
        proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
        proxy_next_upstream_tries 2;
        proxy_next_upstream_timeout 5s;
        
        # Preserve application headers (X-App-Pool, X-Release-Id)
        proxy_pass_request_headers on;
        
        # Don't buffer to get faster response
        proxy_buffering off;
        
        # Forward client information
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Disable proxy cache
        proxy_cache_bypass \$http_upgrade;
    }

    # Health check endpoint
    location /nginx-health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

echo "========================================="
echo "Nginx configuration generated successfully"
echo "ACTIVE_POOL: ${ACTIVE_POOL}"
echo "BACKUP_POOL: ${BACKUP_POOL}"
echo "PORT: ${PORT}"
echo "========================================="
echo ""
echo "Generated configuration:"
cat /etc/nginx/conf.d/default.conf
echo ""
echo "========================================="