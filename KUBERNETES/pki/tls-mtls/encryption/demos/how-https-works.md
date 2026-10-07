```bash
#Generate RSA Keys (Asymmetric Encryption)
openssl genrsa -out server_private.pem 2048
openssl rsa -in server_private.pem -pubout -out server_public.pem

#Sign and Verify Data (Digital Signature Demo)
echo "Hello, I am the real server." > msg.txt
openssl dgst -sha256 -sign server_private.pem -out msg.sig msg.txt
openssl dgst -sha256 -verify server_public.pem -signature msg.sig msg.txt
Verified OK

#Create a Symmetric AES Key
#This key is like the session key used in TLS for fast encryption.
openssl rand -out aes.key 32
#This file contains your AES session key.

#Encrypt Symmetric Key With RSA Public Key
#Browser → encrypts session key (AES) using server’s public key
#Server → decrypts using private key
#Exactly how TLS handshake works.
openssl rsautl -encrypt -inkey server_public.pem -pubin -in aes.key -out aes.key.enc #Encrypt AES key using RSA public key
openssl rsautl -decrypt -inkey server_private.pem -in aes.key.enc -out aes.key.dec #Decrypt using private key
diff aes.key aes.key.dec #Compare keys
#Output should be empty → the AES key is successfully exchanged.

#Use the AES Key to Encrypt and Decrypt Data
openssl enc -aes-256-cbc -salt -in msg.txt -out msg.enc -pass file:./aes.key #Encrypt message with AES key
openssl enc -aes-256-cbc -d -in msg.enc -out msg_decrypted.txt -pass file:./aes.key #Decrypt

#Imitate a Real TLS Handshake
  # Browser (client) does:
  # Gets server's public key from certificate
  # Generates AES session key
  # Encrypts AES key using server’s public key
  # Sends encrypted key
  # Server decrypts using its private key
  # Both sides now use AES
```