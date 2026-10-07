```bash
#Create Your Own CA (Certificate Authority)
# This is the most powerful part.
# You will create:
  # A CA private key
  # A CA certificate
  # A server certificate signed by your CA
# Just like Let’s Encrypt, but manually.

openssl genrsa -out myCA.key 4096 #reate CA private key
openssl req -x509 -new -nodes -key myCA.key -sha256 -days 1825 -out myCA.pem #Create CA certificate (valid 5 years) This is your root certificate.

#Create a TLS Certificate Signed by Your CA
openssl genrsa -out pinkbank.key 2048 #Generate server key
openssl req -new -key pinkbank.key -out pinkbank.csr #Create CSR (Certificate Signing Request)
#CN pinkbank.com

#Sign CSR using your CA
openssl x509 -req -in pinkbank.csr -CA myCA.pem -CAkey myCA.key -CAcreateserial -out pinkbank.crt -days 825 -sha256

#Make Browser Trust Your CA
# Import myCA.pem into your browser's Trusted Root Certificate Store:
# On Chrome:
  # Settings → Security
  # Manage Certificates
  # Authorities tab
  # Import → choose myCA.pem
# Now your browser will trust any certificate signed by your CA.
# Try opening a local server with your certificate:

python https_server.py

https://localhost/

```