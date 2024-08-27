<img width="1271" alt="Screenshot 2024-08-26 at 9 58 54 PM" src="https://github.com/user-attachments/assets/818e1042-5273-4fd8-a0fc-6165e23333e9">

<img width="420" alt="Screenshot 2024-08-26 at 10 01 18 PM" src="https://github.com/user-attachments/assets/ecd300e4-a540-4acf-91be-984fe4e47414">


Features
- [x] Network Interception: Capture HTTP/HTTPS requests and responses.
- [x] Detailed Logging: View all intercepted network traffic, including headers and body.
- [x] User-Friendly Interface: Simple and intuitive interface to monitor network activity.

Future Features
- [ ] Brotli Decryption: Automatically decompress Brotli-encoded responses to display human-readable content.
- [ ] Request Modification: Allow users to edit and resend intercepted network requests.

Basic Usage

1. Create certificates (See below)
2. Install cerificates in Mac and iOS Simulator
3. Configure certificates in SwiftyProxy
4. Start server (First button) and set wifi proxy (Second button)
5. Start watching your network traffic!

# Creating certificates

Generate the Root Certificate (Root CA)
This certificate will be used to sign the server and client certificates. It must be installed on both the Mac and the simulator.

# Generate the private key for the Root CA
```
openssl genrsa -out nacho-root-key.pem 4096
```

Generate the Root CA certificate
```
openssl req -x509 -new -nodes -key nacho-root-key.pem -sha256 -days 825 -out nacho-root-ca.pem -subj "/C=US/ST=Delaware/L=Wilmington/O=Nacho LLC/CN=Nacho Root CA"
```
2. Generate Certificates for the Server
This certificate will be used by the MITM proxy.

Generate the server's private key
```
openssl genrsa -out nacho-server-key.pem 4096
```

# Create a configuration file for the server certificate (nacho-server.conf)
```
cat > nacho-server.conf <<EOF
[req]
default_bits = 4096
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = AR
ST = Buenos Aires
L = Buenos Aires
O = Nacho
CN = jsonplaceholder.typicode.com

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = jsonplaceholder.typicode.com
EOF
```

# Generate a CSR (Certificate Signing Request) for the server
openssl req -new -key nacho-server-key.pem -config nacho-server.conf -out nacho-server.csr

# Sign the server certificate with the Root CA
openssl x509 -req -in nacho-server.csr -CA nacho-root-ca.pem -CAkey nacho-root-key.pem -CAcreateserial -out nacho-server.crt -days 825 -sha256 -extfile nacho-server.conf -extensions req_ext

Certificate Installation

3. Mac and Simulator:
Install the nacom-root-ca.pem certificate on both the Mac and the simulator. This will be the root certificate that both will trust.

MITM Proxy: Use the nacho-server.crt and nacho-server-key.pem certificates in SwiftyProxyCore.

TIP

Enable Trust in the Simulator
Ensure that the root certificate (nacom-root-ca.pem) is marked as trusted in both the simulator and the Mac’s settings.


In file `SwiftyProxyCore.swift` inside the SwiftyProxyCore Package, 

```
let serverCertPath = """
    """

let serverKeyPath = """
    """
```


Contributing
Contributions are welcome! Please fork this repository and submit a pull request with your improvements.

Contact
For any questions, feel free to reach out via issues or by contacting in [LinkedIn](https://www.linkedin.com/in/ignacio-molina-portoles-a4b844173/)
