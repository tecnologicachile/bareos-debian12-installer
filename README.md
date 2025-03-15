# Bareos Installation Script for Debian 12

## English

This script automates the installation of Bareos on a clean Debian 12 system. It installs all required dependencies, including Apache, PHP, PostgreSQL, and Bareos itself, ensuring a fully functional backup solution with a web interface.

### Features:
- Installs and configures Apache and PHP correctly.
- Installs PostgreSQL and sets up the database for Bareos.
- Installs Bareos components (Director, Storage, and File daemon).
- Configures the WebUI with an admin user.
- Provides a test PHP page to verify the installation.

### How to Use:
1. Create the script file:
   ```bash
   nano instalar.sh
   ```
2. Copy and paste the script content into `instalar.sh`.
3. Save the file (`CTRL+X`, then `Y`, then `Enter`).
4. Make the script executable:
   ```bash
   chmod +x instalar.sh
   ```
5. Run the script as root or with sudo:
   ```bash
   sudo ./instalar.sh
   ```

After completion, you can access Bareos WebUI at:
```
http://<server-ip>/bareos-webui
```
Default credentials:
- **User:** admin
- **Password:** admin (change for security)

---

## Español

Este script automatiza la instalación de Bareos en un sistema Debian 12 limpio. Instala todas las dependencias necesarias, incluyendo Apache, PHP, PostgreSQL y Bareos, asegurando una solución de respaldo completamente funcional con una interfaz web.

### Características:
- Instala y configura correctamente Apache y PHP.
- Instala PostgreSQL y configura la base de datos para Bareos.
- Instala los componentes de Bareos (Director, Storage y File daemon).
- Configura la WebUI con un usuario administrador.
- Proporciona una página de prueba PHP para verificar la instalación.

### Cómo Usarlo:
1. Crear el archivo del script:
   ```bash
   nano instalar.sh
   ```
2. Copiar y pegar el contenido del script en `instalar.sh`.
3. Guardar el archivo (`CTRL+X`, luego `Y`, luego `Enter`).
4. Hacer el script ejecutable:
   ```bash
   chmod +x instalar.sh
   ```
5. Ejecutar el script como root o con sudo:
   ```bash
   sudo ./instalar.sh
   ```

Después de la instalación, se puede acceder a Bareos WebUI en:
```
http://<ip-del-servidor>/bareos-webui
```
Credenciales por defecto:
- **Usuario:** admin
- **Contraseña:** admin (cambiar por seguridad)

---

This script simplifies the installation process, ensuring a working Bareos setup without manual intervention.

*Este script simplifica el proceso de instalación, asegurando un Bareos funcional sin intervención manual.*

