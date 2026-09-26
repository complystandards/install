# Comply Standards — self-hosted install

Install an app on your own Linux server (Ubuntu/Debian or any Linux with Docker) with one command:

```bash
curl -fsSL https://raw.githubusercontent.com/complystandards/install/main/install.sh | sudo sh -s -- <app>
```

Replace `<app>` with the name you were given (e.g. `cbam`). You'll be asked for the access key from Comply Standards
and a few questions (your web address, and optionally your brand name). Everything else, including passwords,
keys and HTTPS certificates for a domain name, is set up automatically.

After installation the server looks after itself:
- nightly backups (14 days kept);
- approved updates installed automatically, with a backup first and an automatic roll-back if anything fails;
- stopped services restarted.

Check its state at any time: `cd /opt/<app> && sudo docker compose exec guardian python3 /guardian.py status`

This repository only contains the installer script. It holds no software, keys or client data.
