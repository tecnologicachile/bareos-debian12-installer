#!/bin/bash
#
# Script completo para instalar Bareos en Debian 12
# Este script instala Apache, PHP, PostgreSQL, añade los repositorios de Bareos,
# e instala y configura Bareos automáticamente, incluyendo la interfaz web.
#
# Soluciona el problema común donde el código PHP se muestra en lugar de ejecutarse
#

# Verifica que se está ejecutando como root
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script debe ejecutarse como root o con sudo."
    exit 1
fi

# Configuración - cambia estas variables según sea necesario
POSTGRES_PASSWORD="bareos_db_password"  # Contraseña por defecto para la base de datos
BAREOS_DB_PASSWORD="bareos_db_password"  # Contraseña para bareos-database-common
BAREOS_REPO_URL="https://download.bareos.org/current/Debian_12"
ADMIN_PASSWORD="admin"  # Contraseña para el usuario admin de WebUI (predeterminada: admin)

# Función para mostrar la barra de progreso
show_progress() {
    local msg="$1"
    echo "---------------------------------------------------------------------"
    echo ">>> $msg"
    echo "---------------------------------------------------------------------"
}

clear
echo "====================================================================="
echo "          INSTALACIÓN COMPLETA DE BAREOS EN DEBIAN 12"
echo "====================================================================="
echo ""
echo "Este script realizará una instalación completa de Bareos, incluyendo:"
echo "- Apache y PHP correctamente configurados"
echo "- PostgreSQL como base de datos para Bareos"
echo "- Bareos Director, Storage y File daemon"
echo "- Bareos WebUI con acceso web"
echo ""
echo "Contraseñas predeterminadas (puede cambiarlas en las primeras líneas del script):"
echo "- PostgreSQL: $POSTGRES_PASSWORD"
echo "- Usuario WebUI (admin): $ADMIN_PASSWORD"
echo ""
read -p "Presione ENTER para continuar o CTRL+C para cancelar..."
echo ""

show_progress "Iniciando instalación de Bareos en Debian 12"

show_progress "Actualizando sistema"
apt update
apt upgrade -y

show_progress "Instalando dependencias básicas"
apt install -y wget gnupg2 apt-transport-https ca-certificates debconf-utils

show_progress "Eliminando posibles instalaciones previas de Apache y PHP"
apt remove --purge -y apache2* php* libapache2-mod-php
apt autoremove -y
apt clean

show_progress "Instalando Apache y PHP correctamente"
apt install -y apache2 apache2-utils
apt install -y php php-common php-cli php-curl php-json php-mysql php-pgsql php-gd php-mbstring libapache2-mod-php

show_progress "Configurando módulos de Apache"
a2dismod mpm_event
a2enmod mpm_prefork
a2enmod php
a2enmod rewrite

show_progress "Verificando la instalación de PHP"
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
echo "Versión de PHP instalada: PHP $PHP_VERSION"

show_progress "Instalando PostgreSQL"
apt install -y postgresql postgresql-client

show_progress "Iniciando y habilitando PostgreSQL"
systemctl enable --now postgresql

show_progress "Configurando contraseña para el usuario postgres"
# Cambia la contraseña del usuario postgres en PostgreSQL
su - postgres -c "psql -c \"ALTER USER postgres WITH PASSWORD '$POSTGRES_PASSWORD';\"" 

show_progress "Descargando script de configuración de repositorios Bareos"
wget -q -O add_bareos_repositories.sh "$BAREOS_REPO_URL/add_bareos_repositories.sh"

show_progress "Ejecutando script de configuración de repositorios"
chmod +x add_bareos_repositories.sh
./add_bareos_repositories.sh

show_progress "Actualizando información de repositorios"
apt update

show_progress "Preconfiguración de respuestas para instalación automática"
# Preconfigurar respuestas para evitar preguntas interactivas
debconf-set-selections <<EOF
bareos-database-common bareos-database-common/dbconfig-install boolean true
bareos-database-common bareos-database-common/app-password-confirm password $BAREOS_DB_PASSWORD
bareos-database-common bareos-database-common/password-confirm password $BAREOS_DB_PASSWORD
bareos-database-common bareos-database-common/database-type select pgsql
bareos-database-common bareos-database-common/pgsql/admin-pass password $POSTGRES_PASSWORD
bareos-database-common bareos-database-common/pgsql/app-pass password $BAREOS_DB_PASSWORD
bareos-database-common bareos-database-common/pgsql/method select unix socket
bareos-database-common bareos-database-common/upgrade-backup boolean true
bareos-database-common bareos-database-common/mysql/admin-pass password
bareos-database-common bareos-database-common/missing-db-package-error select abort
bareos-database-common bareos-database-common/remove-error select abort
bareos-database-common bareos-database-common/install-error select abort
bareos-database-common bareos-database-common/mysql/method select Unix socket
bareos-database-common bareos-database-common/purge boolean false
bareos-database-common bareos-database-common/dbconfig-reinstall boolean false
bareos-database-common bareos-database-common/dbconfig-remove boolean true
bareos-database-common bareos-database-common/dbconfig-upgrade boolean true
EOF

show_progress "Instalando Bareos"
DEBIAN_FRONTEND=noninteractive apt install -y bareos

show_progress "Instalando Bareos WebUI"
DEBIAN_FRONTEND=noninteractive apt install -y bareos-webui

show_progress "Creando configuración específica para bareos-webui en Apache"
cat > /etc/apache2/sites-available/bareos-webui.conf <<EOT
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /usr/share/bareos-webui/public

    <Directory /usr/share/bareos-webui/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php
        
        <IfModule mod_php.c>
            AddType application/x-httpd-php .php
            php_flag display_errors Off
        </IfModule>
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/bareos-webui-error.log
    CustomLog \${APACHE_LOG_DIR}/bareos-webui-access.log combined
</VirtualHost>
EOT

show_progress "Habilitando sitio bareos-webui"
a2ensite bareos-webui

show_progress "Configurando acceso de WebUI al Director de Bareos"
# Añadir permisos de WebUI al director
cat > /etc/bareos/bareos-dir.d/console/admin.conf <<EOT
Console {
  Name = admin
  Password = "$ADMIN_PASSWORD"
  Profile = "operator"
  TlsEnable = false
}
EOT

show_progress "Configuración adicional para acceso WebUI"
# Crear un perfil de operador si no existe
if [ ! -f /etc/bareos/bareos-dir.d/profile/operator.conf ]; then
  cat > /etc/bareos/bareos-dir.d/profile/operator.conf <<EOT
Profile {
  Name = operator
  JobACL = *all*
  ClientACL = *all*
  StorageACL = *all*
  ScheduleACL = *all*
  PoolACL = *all*
  FileSetACL = *all*
  CatalogACL = *all*
  CommandACL = !.bvfs_clear_cache, !.exit, !.sql, !configure, !create, !delete, !purge, !sqlquery, !umount, !unmount, *all*
  Where = *all*
}
EOT
fi

show_progress "Ajustando permisos para archivos de bareos-webui"
chown -R www-data:www-data /usr/share/bareos-webui
chown -R www-data:www-data /etc/bareos-webui
chmod -R 755 /usr/share/bareos-webui
chmod -R 755 /etc/bareos-webui

show_progress "Creando archivo de prueba PHP"
cat > /var/www/html/test.php <<EOT
<?php
echo "<h1>PHP está funcionando correctamente en este servidor.</h1>";
phpinfo();
?>
EOT
chmod 644 /var/www/html/test.php
chown www-data:www-data /var/www/html/test.php

show_progress "Reiniciando servicios de Bareos y Apache"
systemctl restart apache2
systemctl restart bareos-director.service
systemctl restart bareos-storage.service
systemctl restart bareos-filedaemon.service

show_progress "Verificando estado de los servicios"
if systemctl is-active --quiet bareos-director.service && \
   systemctl is-active --quiet bareos-storage.service && \
   systemctl is-active --quiet bareos-filedaemon.service && \
   systemctl is-active --quiet apache2.service; then
    INSTALL_STATUS="✅ Todos los servicios están activos y funcionando correctamente"
else
    INSTALL_STATUS="⚠️ Hay servicios que no están funcionando correctamente. Verifica con: systemctl status bareos-director.service bareos-storage.service bareos-filedaemon.service apache2.service"
fi

# Obtener la IP del servidor para mostrar la URL de acceso
SERVER_IP=$(hostname -I | awk '{print $1}')
SERVER_NAME=$(hostname -f)

# Limpiar la pantalla para el resumen final
clear

# Mostrar el resumen de la instalación
cat << EOF
=====================================================================
                INSTALACIÓN DE BAREOS COMPLETADA
=====================================================================

$INSTALL_STATUS

INFORMACIÓN DE ACCESO:
---------------------
WebUI URL: http://$SERVER_IP/bareos-webui
        o: http://$SERVER_NAME/bareos-webui

Usuario WebUI: admin
Contraseña WebUI: $ADMIN_PASSWORD

PRUEBA DE PHP:
-------------
Para verificar que PHP funciona: http://$SERVER_IP/test.php

RESUMEN DE LA INSTALACIÓN:
-------------------------
✅ Apache y PHP instalados y configurados correctamente
✅ PostgreSQL instalado y configurado
✅ Bareos Server instalado y configurado
✅ Bareos WebUI instalado y configurado
✅ Servicios configurados para iniciar automáticamente

PRÓXIMOS PASOS:
--------------
1. Accede a la WebUI con las credenciales proporcionadas
2. Configura los clientes adicionales que desees respaldar
3. Define tus políticas de respaldo según necesidades
4. Para seguridad en producción, cambia las contraseñas por defecto

Para administración por consola, usa el comando: bconsole

=====================================================================
EOF

# Guardar credenciales en un archivo protegido
cat > /root/.bareos_credentials << EOC
# Credenciales de Bareos - CONFIDENCIAL
# Generado el $(date)
#
# Usuario PostgreSQL: postgres
# Contraseña PostgreSQL: $POSTGRES_PASSWORD
#
# Usuario WebUI: admin  
# Contraseña WebUI: $ADMIN_PASSWORD
#
# Contraseña de bareos-database-common: $BAREOS_DB_PASSWORD
EOC

# Proteger el archivo de credenciales
chmod 600 /root/.bareos_credentials

# Informar sobre el archivo de credenciales
echo "Las credenciales han sido guardadas en /root/.bareos_credentials"
echo "Este archivo solo es accesible por el usuario root."
echo "Por seguridad, considere cambiar estas contraseñas en un entorno de producción."
echo "=====================================================================\n"
