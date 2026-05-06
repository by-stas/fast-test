# Local Kerberos files

This directory is used by `docker-compose.yml` for local container testing.

Place a local development keytab at:

```text
deploy/local/app.keytab
```

The `*.keytab` pattern is ignored by Git. Update `krb5.conf` for your Active
Directory realm and domain controllers before running the backend locally.
