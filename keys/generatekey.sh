#!/bin/sh

days=365

openssl genrsa -out key.pem 1024
openssl req -new -key key.pem -out request.pem
openssl x509 -req -days $days -in request.pem -signkey key.pem -out certificate.pem

#openssl x509 -inform der -in certificate.crt -out certificate.pem
