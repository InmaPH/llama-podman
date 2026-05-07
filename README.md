This system simulates an enterprise air-gapped inference stack:

- systemd slice isolates compute resources
- Podman runs rootless containers
- Quadlets define persistent services
- models are treated as signed artifacts
- network is disabled at inference layer

This is a local-first AI appliance architecture.