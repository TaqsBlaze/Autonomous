#!/bin/bash

# Enhanced Security Tools Installation Script for ParrotOS 6.1
# This script should be run with root privileges
# Purpose: Install security testing, OSINT, and reconnaissance tools for authorized testing

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or with sudo"
    exit 1
fi

# Update system first
echo "[+] Updating system packages..."
apt update && apt upgrade -y

# Function to install a package if not already installed
install_package() {
    if ! dpkg -l | grep -q "^ii  $1 "; then
        echo "[+] Installing $1..."
        apt install -y $1
    else
        echo "[*] $1 is already installed"
    fi
}

# Array of security tools
TOOLS=(
    # Network and Web Tools
    "nmap"              # Network scanner
    "wireshark"         # Network protocol analyzer
    "metasploit-framework" # Penetration testing framework
    "burpsuite"         # Web application security testing
    "sqlmap"           # SQL injection testing
    "nikto"            # Web server scanner
    "dirb"             # Web content scanner
    "hydra"            # Password cracking tool
    "john"             # Password cracker
    "net-tools"        # Network utilities
    "aircrack-ng"      # Wireless testing
    "gobuster"         # Directory/file enumeration
    "exploitdb"        # Exploit database
    
    # DNS and Domain Tools
    "bind9-dnsutils"   # DNS utilities
    "whois"            # Domain registration info
    "dnsenum"          # DNS enumeration
    "dnsmap"           # DNS mapping
    "dnsrecon"         # DNS reconnaissance
    
    # OSINT Tools
    "maltego"          # OSINT and forensics
    "spiderfoot"       # OSINT automation
    "theharvester"     # Email and subdomain harvesting
    "recon-ng"         # Web reconnaissance
    "osrframework"     # Username checking
    
    # Social Engineering Tools
    "set"              # Social Engineering Toolkit
    "beef-xss"         # Browser exploitation
    "wifiphisher"      # Social engineering attacks
    
    # Additional Utilities
    "curl"             # Data transfer tool
    "phantomjs"        # Headless browser
    "proxychains"      # Proxy tool
    "tor"              # Anonymity network
    "git"              # Version control
    "python3-venv"     # Python virtual environment
    "python3-pip"      # Python package installer
    "golang"           # Go language for certain tools
)

echo "[+] Starting installation of system packages..."

# Install each tool
for tool in "${TOOLS[@]}"; do
    install_package "$tool"
done

# Create main directory for security tools
echo "[+] Creating security tools directory..."
mkdir -p /opt/security-tools
cd /opt/security-tools

# Set up Python virtual environment
echo "[+] Setting up Python virtual environment..."
VENV_PATH="/opt/security-tools/venv"
python3 -m venv $VENV_PATH

# Create activation script
cat > /opt/security-tools/activate-security-tools.sh << EOL
#!/bin/bash
source ${VENV_PATH}/bin/activate
export PATH="\${PATH}:${VENV_PATH}/bin"
echo "[+] Security tools Python environment activated"
EOL

chmod +x /opt/security-tools/activate-security-tools.sh

# Install Python tools within the virtual environment
echo "[+] Installing Python-based security tools..."
source $VENV_PATH/bin/activate

# Update pip in the virtual environment
$VENV_PATH/bin/pip install --upgrade pip

# Python tools array
PYTHON_TOOLS=(
    "shodan"           # Shodan API client
    "twint @ git+https://github.com/twintproject/twint.git"  # Twitter scraping tool
    "instaloader"      # Instagram scraping tool
    "holehe"          # Email OSINT tool
    "sherlock-project" # Social media username search
    "maigret"         # Social media presence finder
    "social-analyzer" # Social media analysis tool
    "dmitry"          # Deepmagic Information Gathering Tool
    "requests"        # Required by many tools
    "beautifulsoup4"  # Required by many tools
    "lxml"           # Required by many tools
    "aiohttp"        # Required by many tools
    "asyncio"        # Required by many tools
    "scapy"          # Network packet manipulation
    "pyOpenSSL"      # SSL/TLS toolkit
    "paramiko"       # SSH protocol
)

# Install each Python tool in the virtual environment
for tool in "${PYTHON_TOOLS[@]}"; do
    echo "[+] Installing $tool..."
    $VENV_PATH/bin/pip install $tool
done

# Clone additional tools from GitHub
echo "[+] Cloning additional tools from GitHub..."
git clone https://github.com/danielmiessler/SecLists.git
git clone https://github.com/OWASP/Amass.git
git clone https://github.com/laramies/theHarvester.git
git clone https://github.com/sherlock-project/sherlock.git
git clone https://github.com/smicallef/spiderfoot.git
git clone https://github.com/lanmaster53/recon-ng.git
git clone https://github.com/thewhiteh4t/FinalRecon.git
git clone https://github.com/s0md3v/Photon.git

# Install Amass using Go
echo "[+] Installing Amass..."
go install -v github.com/OWASP/Amass/v3/...@master

# Create symbolic links for Python tools
echo "[+] Creating symbolic links for Python tools..."
for script in $VENV_PATH/bin/*; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        script_name=$(basename "$script")
        # Exclude python interpreter and pip
        if [[ ! "$script_name" =~ ^(python|pip) ]]; then
            ln -sf "$script" "/usr/local/bin/$script_name"
        fi
    fi
done

# Create wordlists directory and download common wordlists
echo "[+] Setting up wordlists..."
mkdir -p /opt/wordlists
cd /opt/wordlists
wget https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/namelist.txt
wget https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-5000.txt

# Create documentation
cat > /opt/security-tools/README.md << EOL
# Security Tools Installation

## Python Environment
To use Python-based tools:
1. Activate the environment: \`source /opt/security-tools/activate-security-tools.sh\`
2. Use the tools as needed
3. When finished: \`deactivate\`

## Tool Locations
- System tools: Available in PATH
- Python tools: In virtual environment
- Additional tools: /opt/security-tools/
- Wordlists: /opt/wordlists/

## Installed Tools
### Network & Web
- nmap, wireshark, metasploit-framework
- burpsuite, sqlmap, nikto, dirb
- hydra, john, aircrack-ng, gobuster

### DNS & Domain
- dnsutils, whois, dnsenum, dnsmap, dnsrecon

### OSINT
- maltego, spiderfoot, theharvester
- recon-ng, osrframework

### Python Tools
$(for tool in "${PYTHON_TOOLS[@]}"; do echo "- $tool"; done)

## Notes
- Some tools may require additional configuration
- Always use tools responsibly and legally
- Check tool documentation for usage details
EOL

# Set proper permissions
chown -R root:root /opt/security-tools /opt/wordlists
chmod -R 755 /opt/security-tools /opt/wordlists

# Deactivate virtual environment
deactivate

echo "[+] Installation complete!"
echo "[*] Please use these tools responsibly and only on systems you have permission to test."
echo "[*] To use Python tools, first run: source /opt/security-tools/activate-security-tools.sh"
echo "[*] See /opt/security-tools/README.md for full documentation"

# Print versions of key tools
echo "[+] Installed tool versions:"
nmap --version | head -n 1
metasploit-framework --version
sqlmap --version
nikto -Version
echo "Wireshark: $(wireshark --version)"
echo "TheHarvester: $(theharvester --version)"
echo "Amass: $(amass --version)"
