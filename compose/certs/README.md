# Certs management

If a new service is added that uses a different host name ie. the service name in compose.yml, then the self signed cert will need recreating.

From the root of this README, run the following:

```
openssl req -x509 -newkey rsa:4096 -keyout https/aspnetapp.key -out https/aspnetapp.crt -days 3650 -nodes -config cert.conf -extensions v3_req
```

Inspect the generated cert with the following and ensure the additional SAN is present:

```
openssl x509 -in https/aspnetapp.crt -text -noout
```

Then generate the .pfx as follows:

```
openssl pkcs12 -export -out https/aspnetapp.pfx -inkey https/aspnetapp.key -in https/aspnetapp.crt
```

Use `password` as the password when prompted.
