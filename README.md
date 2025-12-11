# Pangolin Newt Systemd Service

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Issues](https://img.shields.io/github/issues/Malith-Rukshan/pangolin-newt-service)](https://github.com/Malith-Rukshan/pangolin-newt-service/issues)
[![GitHub Stars](https://img.shields.io/github/stars/Malith-Rukshan/pangolin-newt-service)](https://github.com/Malith-Rukshan/pangolin-newt-service/stargazers)

Run [Pangolin Newt](https://github.com/fosrl/newt) as a persistent background service on Linux using systemd. Prevents Newt from stopping when you close your terminal.

## What is Pangolin Newt?

[Newt](https://github.com/fosrl/newt) is a WireGuard tunnel client that works with [Pangolin](https://pangolin.net) to securely expose private resources without complex network configurations. It's part of the Pangolin tunneling platform ecosystem.

**Problem:** When you run Newt from the command line (`newt --id ... --secret ...`), it stops when you close the terminal.

**Solution:** This repository provides an automated script to set up Newt as a systemd service that runs persistently in the background.

## 🚀 Quick Setup

### Prerequisites

1. Install Newt using Pangolin's official installer
2. Get your Newt credentials (ID, secret, endpoint) from Pangolin dashboard

### Automated Installation

Run this one-liner and paste your Pangolin command when prompted:

```bash
curl -sSL https://raw.githubusercontent.com/Malith-Rukshan/pangolin-newt-service/main/setup-newt-service.sh | sudo bash
```

The script will:
- ✅ Verify Newt binary installation
- ✅ Extract your ID, secret, endpoint, and flags
- ✅ Create systemd service configuration
- ✅ Enable and start the service automatically

**Example Pangolin command:**
```bash
newt --id b87pbof72mk98nc --secret 6kwq2g92uihpmue0fvlymjeupuiwbhejd0fladk1iu68j6g4 --endpoint https://mydomain.com --accept-clients
```

## 📋 Manual Setup

If you prefer manual configuration:

### 1. Create Service File

```bash
sudo nano /etc/systemd/system/newt.service
```

### 2. Add Configuration

Replace placeholders with your actual values from Pangolin:

```ini
[Unit]
Description=Newt - Pangolin Tunnel Client
After=network.target

[Service]
ExecStart=/usr/local/bin/newt --id YOUR_ID --secret YOUR_SECRET --endpoint https://your-endpoint.com
Restart=always
User=root

[Install]
WantedBy=multi-user.target
```

**Note:** Add any additional flags like `--accept-clients`, `--log-level DEBUG`, etc.

### 3. Enable and Start

```bash
sudo systemctl daemon-reload
sudo systemctl enable newt.service
sudo systemctl start newt.service
```

### 4. Verify Status

```bash
sudo systemctl status newt.service
```

## 🔧 Service Management

### View Real-time Logs
```bash
sudo journalctl -u newt.service -f
```

### Restart Service
```bash
sudo systemctl restart newt.service
```

### Stop Service
```bash
sudo systemctl stop newt.service
```

### Disable Auto-start
```bash
sudo systemctl disable newt.service
```

### Check Service Status
```bash
sudo systemctl status newt.service
```

## 🐛 Troubleshooting

**Service fails to start:**
- Verify Newt binary exists: `ls -la /usr/local/bin/newt`
- Check your credentials are correct
- View logs: `sudo journalctl -u newt.service -n 50`

**Binary not found:**
- Install Newt first using Pangolin's official installer
- Ensure binary is at `/usr/local/bin/newt`

**Permission issues:**
- The service runs as root by default
- Ensure the script is run with `sudo`

## 📦 What's Included

- `setup-newt-service.sh` - Automated service creation script
- `newt.service.template` - Manual service configuration template
- Complete documentation and examples

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Related Links

- [Pangolin Official Website](https://pangolin.net)
- [Pangolin Documentation](https://docs.pangolin.net)
- [Newt GitHub Repository](https://github.com/fosrl/newt)
- [Pangolin GitHub Organization](https://github.com/fosrl)

## ⭐ Show Your Support

If this project helped you, please give it a ⭐️!

## 📧 Contact

Created by [@Malith-Rukshan](https://malith.dev)

Issues and questions: [GitHub Issues](https://github.com/Malith-Rukshan/pangolin-newt-service/issues)

---

**Keywords:** Pangolin, Newt, systemd, Linux service, WireGuard tunnel, Pangolin Newt service, background service, daemon, self-hosted tunneling, Pangolin client
