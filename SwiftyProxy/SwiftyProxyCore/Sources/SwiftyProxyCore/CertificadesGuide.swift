//1. Generar el Certificado Raíz (Root CA)
//Este certificado se utilizará para firmar los certificados del servidor y cliente. Debe ser instalado en la Mac y el simulador.
//# Generar la clave privada para el Root CA
//openssl genrsa -out nacom-root-key.pem 4096

// Generar el certificado Root CA
//openssl req -x509 -new -nodes -key nacom-root-key.pem -sha256 -days 825 -out nacom-root-ca.pem -subj "/C=US/ST=Delaware/L=Wilmington/O=Nacom LLC/CN=Nacom Root CA"

//2. Generar Certificados para el Servidor
//Este certificado será utilizado por el proxy MITM.

//Generar la clave privada del servidor
//openssl genrsa -out nacom-server-key.pem 4096

//# Crear un archivo de configuración para el certificado del servidor (nacom-server.conf)
//cat > nacom-server.conf <<EOF
//[req]
//default_bits = 4096
//prompt = no
//default_md = sha256
//distinguished_name = dn
//req_extensions = req_ext
//
//[dn]
//C = US
//ST = Delaware
//L = Wilmington
//O = Nacom LLC
//CN = jsonplaceholder.typicode.com
//
//[req_ext]
//subjectAltName = @alt_names
//
//[alt_names]
//DNS.1 = jsonplaceholder.typicode.com
//EOF

//# Generar una CSR (Certificate Signing Request) para el servidor
//openssl req -new -key nacom-server-key.pem -config nacom-server.conf -out nacom-server.csr

//# Firmar el certificado del servidor con el Root CA
//openssl x509 -req -in nacom-server.csr -CA nacom-root-ca.pem -CAkey nacom-root-key.pem -CAcreateserial -out nacom-server.crt -days 825 -sha256 -extfile nacom-server.conf -extensions req_ext
//3. Generar Certificados para el Cliente
//Si necesitas certificados específicos para el cliente, puedes generarlos de manera similar, ajustando los valores de CN y DNS en el archivo de configuración.

//4. Instalación de Certificados
//Mac y Simulador: Instala el certificado nacom-root-ca.pem en la Mac y en el simulador. Este será el certificado raíz que ambos confiarán.
//Proxy MITM: Usa el certificado nacom-server.crt y la clave nacom-server-key.pem en tu proxy MITM.
//5. Habilitar Confianza en el Simulador
//Asegúrate de que el certificado raíz (nacom-root-ca.pem) esté marcado como confiable en la configuración del simulador y la Mac.


