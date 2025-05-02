#!/bin/bash

# Warna 
b='\033[34;1m'
g='\033[32;1m'
c='\033[36;1m'
r='\033[31;1m'
y='\033[33;1m'
n='\033[0m'

# Tampilan Awall
clear
VERSION="1.0.0"
LOG_FILE="install.log"
BACKUP_DIR="$HOME/backup_$(date +%F_%H-%M-%S)"
SPINNER_TYPE="spinner"
DRY_RUN=false
NO_COLOR=false
SKIP_PIP=false
SKIP_NODE=false
SKIP_RUBY=false
ONLY_SYSTEM=false
ONLY_PYTHON=false
ONLY_NODE=false
ONLY_RUBY=false
error_exit() {
  echo "ERROR: $1" >&2 | tee -a "$LOG_FILE"
  exit 1
}
check_status() {
  if [ $? -ne 0 ]; then
    error_exit "$1"
  fi
}
show_help() {
  echo "Penggunaan: $0 [OPSIONAL]" | lolcat 2>/dev/null || echo "Penggunaan: $0 [OPSIONAL]"
  echo "Script untuk mengatur lingkungan Termux/Linux dengan instalasi paket dan pustaka."
  echo "Otomatis melewati modul yang sudah terinstal."
  echo ""
  echo "Opsi:"
  echo "  --spinner TYPE       Pilih tipe animasi spinner (default, dots, bars, arrow)"
  echo "  --no-color          Nonaktifkan warna pada output"
  echo "  --skip-pip          Lewati pembaruan pip dan instalasi pustaka Python"
  echo "  --skip-node         Lewati instalasi paket Node.js"
  echo "  --skip-ruby         Lewati instalasi Ruby gem"
  echo "  --only-system       Instal hanya paket sistem"
  echo "  --only-python       Instal hanya Python dan pustaka"
  echo "  --only-node         Instal hanya Node.js dan paket"
  echo "  --only-ruby         Instal hanya Ruby dan gem"
  echo "  --dry-run           Simulasi tanpa menjalankan perintah instalasi"
  echo "  --interactive       Mode interaktif untuk memilih paket"
  echo "  --backup            Backup konfigurasi sebelum instalasi"
  echo "  --setup-shell       Tambahkan alias berguna ke ~/.bashrc"
  echo "  --github-tool REPO  Instal alat dari GitHub (contoh: ohmyzsh/ohmyzsh)"
  echo "  --cron              Jadwalkan pembaruan otomatis mingguan"
  echo "  --version           Tampilkan versi script"
  echo "  --check-update      Periksa pembaruan script dari GitHub"
  echo "  --help              Tampilkan bantuan ini"
  exit 0
}
spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\\'
  local message=$2
  while [ -d /proc/$pid ]; do
    local temp=${spinstr#?}
    if [ "$NO_COLOR" = true ]; then
      printf "\r[*] %s [%c] " "$message" "${spinstr:0:1}"
    else
      printf "\r[*] \e[32m%s [\e[31m%c\e[32m]\e[0m " "$message" "${spinstr:0:1}"
    fi
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
  done
  if [ "$NO_COLOR" = true ]; then
    printf "\r[*] %s [Done]          \n" "$message"
  else
    printf "\r[*] \e[32m%s [Done]\e[0m          \n" "$message"
  fi
}
spinner_dots() {
  local pid=$1
  local delay=0.5
  local spinstr='....'
  local message=$2
  while [ -d /proc/$pid ]; do
    if [ "$NO_COLOR" = true ]; then
      printf "\r[*] %s %s" "$message" "${spinstr}"
    else
      printf "\r[*] \e[32m%s \e[33m%s\e[32m\e[0m" "$message" "${spinstr}"
    fi
    spinstr=${spinstr#?}.${spinstr:0:1}
    sleep $delay
  done
  if [ "$NO_COLOR" = true ]; then
    printf "\r[*] %s [Done]          \n" "$message"
  else
    printf "\r[*] \e[32m%s [Done]\e[0m          \n" "$message"
  fi
}
spinner_bars() {
  local pid=$1
  local delay=0.2
  local spinstr='█▉▊▋▌'
  local message=$2
  while [ -d /proc/$pid ]; do
    local temp=${spinstr#?}
    if [ "$NO_COLOR" = true ]; then
      printf "\r[*] %s [%c] " "$message" "${spinstr:0:1}"
    else
      printf "\r[*] \e[32m%s [\e[34m%c\e[32m]\e[0m " "$message" "${spinstr:0:1}"
    fi
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
  done
  if [ "$NO_COLOR" = true ]; then
    printf "\r[*] %s [Done]          \n" "$message"
  else
    printf "\r[*] \e[32m%s [Done]\e[0m          \n" "$message"
  fi
}
spinner_arrow() {
  local pid=$1
  local delay=0.3
  local spinstr='-> --> ---> ---->'
  local message=$2
  local i=0
  local frames=(${spinstr})
  while [ -d /proc/$pid ]; do
    if [ "$NO_COLOR" = true ]; then
      printf "\r[*] %s [%s] " "$message" "${frames[$i]}"
    else
      printf "\r[*] \e[32m%s [\e[36m%s\e[32m]\e[0m " "$message" "${frames[$i]}"
    fi
    i=$(( (i + 1) % ${#frames[@]} ))
    sleep $delay
  done
  if [ "$NO_COLOR" = true ]; then
    printf "\r[*] %s [Done]          \n" "$message"
  else
    printf "\r[*] \e[32m%s [Done]\e[0m          \n" "$message"
  fi
}
select_spinner() {
  local pid=$1
  local message=$2
  case $SPINNER_TYPE in
    dots)
      spinner_dots "$pid" "$message"
      ;;
    bars)
      spinner_bars "$pid" "$message"
      ;;
    arrow)
      spinner_arrow "$pid" "$message"
      ;;
    *)
      spinner "$pid" "$message"
      ;;
  esac
}
progress_bar() {
  local current=$1
  local total=$2
  local message=$3
  local width=30
  local percent=$((current * 100 / total))
  local filled=$((width * current / total))
  local empty=$((width - filled))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+=" "; done
  if [ "$NO_COLOR" = true ]; then
    printf "\r[*] %s: [%s] %d%%" "$message" "$bar" "$percent"
  else
    printf "\r[*] \e[32m%s: [\e[34m%s\e[32m] %d%%\e[0m" "$message" "$bar" "$percent"
  fi
}
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
  elif [ -d /data/data/com.termux ]; then
    OS="Termux"
  else
    OS="Unknown"
  fi
  echo -e "${b}[*] Sistem Terdeteksi : $OS" | tee -a "$LOG_FILE"
  case $OS in
    "Termux")
      PKG_MANAGER="pkg"
      ;;
    "Ubuntu"|"Debian"*)
      PKG_MANAGER="apt"
      ;;
    *)
      error_exit "Sistem tidak didukung."
      ;;
  esac
}
check_dependencies() {
  for cmd in curl git; do
    if ! command -v "$cmd" &>/dev/null; then
      error_exit "Perintah $cmd tidak ditemukan. Silakan instal terlebih dahulu."
    fi
  done
}
check_internet() {
  ping -c 1 google.com &>/dev/null || error_exit "Tidak ada koneksi internet."
}
backup_system() {
  echo "[*] Membuat backup konfigurasi..." | tee -a "$LOG_FILE"
  mkdir -p "$BACKUP_DIR"
  cp -r ~/.bashrc ~/.bash_profile "$BACKUP_DIR" 2>/dev/null
  echo "[*] Backup disimpan ke $BACKUP_DIR" | tee -a "$LOG_FILE"
}
setup_shell() {
  echo "[*] Menambahkan alias berguna ke ~/.bashrc..." | tee -a "$LOG_FILE"
  cat <<EOL >> ~/.bashrc
alias ll='ls -la'
alias update='$PKG_MANAGER update && $PKG_MANAGER upgrade'
alias clean='$PKG_MANAGER autoclean'
EOL
  source ~/.bashrc 2>/dev/null
}
install_github_tool() {
  local repo=$1
  echo "[*] Mengunduh $repo dari GitHub..." | tee -a "$LOG_FILE"
  if $DRY_RUN; then
    echo "[DRY-RUN] Akan mengunduh https://github.com/$repo.git"
  else
    git clone "https://github.com/$repo.git" &>/dev/null &
    select_spinner $! "Mengunduh $repo"
  fi
}
setup_cron() {
  echo "[*] Menyiapkan pembaruan otomatis mingguan..." | tee -a "$LOG_FILE"
  if $DRY_RUN; then
    echo "[DRY-RUN] Akan menambahkan cron job: 0 0 * * 0 $0 --only-system"
  else
    echo "0 0 * * 0 $0 --only-system" | crontab -
  fi
}
check_update() {
  echo "[*] Memeriksa pembaruan script..." | tee -a "$LOG_FILE"
  LATEST_VERSION=$(curl -s https://api.github.com/repos/USERNAME/REPO/releases/latest | jq -r .tag_name 2>/dev/null)
  if [[ "$LATEST_VERSION" && "$LATEST_VERSION" != "$VERSION" ]]; then
    echo "[*] Versi baru tersedia: $LATEST_VERSION (saat ini: $VERSION). Unduh dari GitHub." | tee -a "$LOG_FILE"
  else
    echo "[*] Script sudah menggunakan versi terbaru: $VERSION" | tee -a "$LOG_FILE"
  fi
  exit 0
}
check_system_package() {
  local pkg=$1
  if command -v "$pkg" &>/dev/null; then
    return 0
  else
    return 1
  fi
}
check_python_library() {
  local lib=$1
  if pip show "$lib" &>/dev/null; then
    return 0
  else
    return 1
  fi
}
check_ruby_gem() {
  local gem=$1
  if gem list -i "$gem" &>/dev/null; then
    return 0
  else
    return 1
  fi
}
check_node_package() {
  local pkg=$1
  if npm list -g "$pkg" &>/dev/null; then
    return 0 
  else
    return 1 
  fi
}
install_system() {
  echo "[*] Memperbarui dan meningkatkan sistem..." | tee -a "$LOG_FILE"
  if $DRY_RUN; then
    echo "[DRY-RUN] Akan menjalankan $PKG_MANAGER update && $PKG_MANAGER upgrade"
  else
    $PKG_MANAGER update -y && $PKG_MANAGER upgrade -y &>/dev/null &
    select_spinner $! "Memperbarui dan meningkatkan sistem"
  fi
  check_status "Gagal memperbarui atau meningkatkan sistem."
  echo "[*] Menginstall paket sistem (modul)..." | tee -a "$LOG_FILE"
  total_pkgs=${#PKGS[@]}
  current_pkg=0
  for PKG in "${PKGS[@]}"; do
    current_pkg=$((current_pkg + 1))
    progress_bar $current_pkg $total_pkgs "Menginstall paket sistem"
    echo -n " ($PKG)..." | tee -a "$LOG_FILE"
    if check_system_package "$PKG"; then
      echo "[-] $PKG sudah terinstal, melewati..." | tee -a "$LOG_FILE"
      continue
    fi
    if $DRY_RUN; then
      echo "[DRY-RUN] Akan menginstall $PKG"
    else
      if $PKG_MANAGER install -y "$PKG" &>/dev/null; then
        select_spinner $! "Menginstall $PKG"
      else
        echo "[-] Gagall menginstall $PKG. Melanjutkan ke paket berikutnya." | tee -a "$LOG_FILE"
      fi
    fi
  done
  printf "\n"
}
install_python() {
  if [ "$SKIP_PIP" = true ]; then
    echo "[-] Melewati pembaruan pip dan instalasi pustaka Python." | tee -a "$LOG_FILE"
    return
  fi
  echo "[*] Memperbarui pip..." | tee -a "$LOG_FILE"
  if $DRY_RUN; then
    echo "[DRY-RUN] Akan memperbarui pip"
  else
    python3 -m pip install --upgrade pip --user &>/dev/null &
    select_spinner $! "Memperbarui pip"
  fi
  check_status "Gagall memperbarui pip."
  echo "[*] Menginstall pustaka Python (modul)..." | tee -a "$LOG_FILE"
  total_libs=${#PYTHON_LIBS[@]}
  current_lib=0
  for LIB in "${PYTHON_LIBS[@]}"; do
    current_lib=$((current_lib + 1))
    progress_bar $current_lib $total_libs "Menginstall pustaka Python"
    echo -n " ($LIB)..." | tee -a "$LOG_FILE"
    if check_python_library "$LIB"; then
      echo "[-] $LIB sudah terinstal, melewati..." | tee -a "$LOG_FILE"
      continue
    fi
    if $DRY_RUN; then
      echo "[DRY-RUN] Akan menginstall $LIB"
    else
      if pip install "$LIB" --user &>/dev/null; then
        select_spinner $! "Menginstall $LIB"
      else
        echo "[-] Gagal menginstall $LIB. Melanjutkan ke pustaka berikutnya." | tee -a "$LOG_FILE"
      fi
    fi
  done
  printf "\n"
}
install_node() {
  if [ "$SKIP_NODE" = true ]; then
    echo "[-] Melewati instalasi paket Node.js." | tee -a "$LOG_FILE"
    return
  fi
  echo "[*] Menginstall Node.js package: bash-obfuscate..." | tee -a "$LOG_FILE"
  if check_node_package "bash-obfuscate"; then
    echo "[-] bash-obfuscate sudah terinstal, melewati..." | tee -a "$LOG_FILE"
    return
  fi
  if $DRY_RUN; then
    echo "[DRY-RUN] Akan menginstall bash-obfuscate"
  else
    npm install -g bash-obfuscate &>/dev/null &
    select_spinner $! "Menginstall bash-obfuscate"
  fi
  check_status "Gagal menginstall bash-obfuscate."
}
install_ruby() {
  if [ "$SKIP_RUBY" = true ]; then
    echo "[-] Melewati instalasi Ruby gem." | tee -a "$LOG_FILE"
    return
  fi
  echo "[*] Menginstall Ruby gem: lolcat..." | tee -a "$LOG_FILE"
  if check_ruby_gem "lolcat"; then
    echo "[-] lolcat sudah terinstal, melewati..." | tee -a "$LOG_FILE"
    return
  fi
  if $DRY_RUN; then
    echo "[DRY-RUN] Akan menginstall lolcat"
  else
    gem install lolcat &>/dev/null &
    select_spinner $! "Menginstall lolcat"
  fi
  check_status "Gagall menginstall lolcat."
}
while [[ $# -gt 0 ]]; do
  case $1 in
    --spinner)
      SPINNER_TYPE="$2"
      shift 2
      ;;
    --no-color)
      NO_COLOR=true
      shift
      ;;
    --skip-pip)
      SKIP_PIP=true
      shift
      ;;
    --skip-node)
      SKIP_NODE=true
      shift
      ;;
    --skip-ruby)
      SKIP_RUBY=true
      shift
      ;;
    --only-system)
      ONLY_SYSTEM=true
      shift
      ;;
    --only-python)
      ONLY_PYTHON=true
      shift
      ;;
    --only-node)
      ONLY_NODE=true
      shift
      ;;
    --only-ruby)
      ONLY_RUBY=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --interactive)
      INTERACTIVE=true
      shift
      ;;
    --backup)
      BACKUP=true
      shift
      ;;
    --setup-shell)
      SETUP_SHELL=true
      shift
      ;;
    --github-tool)
      install_github_tool "$2"
      exit 0
      ;;
    --cron)
      setup_cron
      exit 0
      ;;
    --version)
      echo "Versi: $VERSION"
      exit 0
      ;;
    --check-update)
      check_update
      ;;
    --help)
      show_help
      ;;
    *)
      shift
      ;;
  esac
done
echo -e "${r}[*] Log instalasi disimpan ke $LOG_FILE" | tee "$LOG_FILE"
echo ""
detect_os
check_dependencies
check_internet
if [ -f "config.txt" ]; then
  echo "[*] Membaca konfigurasi dari config.txt..." | tee -a "$LOG_FILE"
  source config.txt
fi
PKGS=${PKGS:-"python python2 nodejs-lts ruby bash cowsay figlet neofetch vim curl git jq coreutils ncurses-utils ossp-uuid mpv ffmpeg sox zip unzip binutils clang make cmake xz busybox tree"}
PYTHON_LIBS=${PYTHON_LIBS:-"psutil requests mechanize rich rich-cli pyliblzma"}
PKGS=($PKGS)
PYTHON_LIBS=($PYTHON_LIBS)
if [ "$INTERACTIVE" = true ] && command -v dialog &>/dev/null; then
  echo "[*] Memulai mode interaktif..." | tee -a "$LOG_FILE"
  PKGS=$(dialog --checklist "Pilih paket untuk diinstal:" 20 50 10 \
    python "Python 3" on \
    python2 "Python 2" off \
    nodejs-lts "Node.js LTS" on \
    ruby "Ruby" on \
    vim "Vim editor" on \
    git "Git version control" on \
    curl "Curl utility" on \
    --output-fd 1)
  PYTHON_LIBS=$(dialog --checklist "Pilih pustaka Python untuk diinstal:" 15 40 5 \
    psutil "System monitoring" on \
    requests "HTTP requests" on \
    mechanize "Web scraping" on \
    rich "Rich text formatting" on \
    rich-cli "Rich CLI tools" on \
    pyliblzma "LZMA compression" on \
    --output-fd 1)
fi
check_modules() {
  command -v git >/dev/null 2>&1 && command -v curl >/dev/null 2>&1
}
if [ "$DRY_RUN" = false ] && [ "$INTERACTIVE" != true ]; then
  if check_modules; then
    echo ""
    echo -e "${g} Modules Sudah Terinstall...!!!"
    echo ""
    read -p "$(echo -e "${r}[ ${g}? ${r}]${y} Apakah Kamu Ingin Install Modules Lagi? ${r}[ ${g}y/n ${r}]${c} : ")" confirm
    echo ""
  else
    echo ""
    echo -e "${r} Modules Blum Terinstall...!!!"
    echo ""
    read -p "$(echo -e "${r}[ ${g}? ${r}]${y} Apakah Kamu Ingin Install Modules? ${r}[ ${g}y/n ${r}]${c} : ")" confirm
  fi
  if [[ "$confirm" != "y" ]]; then
    echo ""
    echo -e "${r}[ ${g}-- ${r}] Instalasi Dibatalkan...!!!${n}" | tee -a "$LOG_FILE"
    echo ""
    echo -e "${g} Mohon Bersabar Sedang Running Tools...!!!"
    sleep 4 
    clear
    echo ""
    echo -e "${g} Menginstall Toolsv8 Tanpa Perlu Menginstall Package Lagii...!!! "
    sleep 4 
    echo -e "${y}"
    git clone https://github.com/Krocoo4578/Goblok.git
    git clone https://github.com/Krocoo4578/Triall.git
    cd Triall
    bash Mode.sh
  fi
fi
if [ "$BACKUP" = true ]; then
  backup_system
fi
if [ "$SETUP_SHELL" = true ]; then
  setup_shell
fi
if [ "$(id -u)" -eq 0 ]; then
  echo "[*] Berjalan sebagai root. Beberapa perintah mungkin tidak memerlukan sudo." | tee -a "$LOG_FILE"
  SUDO=""
else
  echo "[*] Berjalan sebagai pengguna biasa. Menggunakan sudo jika diperlukan." | tee -a "$LOG_FILE"
  SUDO="sudo"
fi
if [ "$ONLY_SYSTEM" = true ]; then
  install_system
elif [ "$ONLY_PYTHON" = true ]; then
  install_python
elif [ "$ONLY_NODE" = true ]; then
  install_node
elif [ "$ONLY_RUBY" = true ]; then
  install_ruby
else
  install_system
  install_python
  install_node
  install_ruby
fi
echo "[*] Membersihkan cache..." | tee -a "$LOG_FILE"
if $DRY_RUN; then
  echo "[DRY-RUN] Akan membersihkan cache $PKG_MANAGER" | tee -a "$LOG_FILE"
else
  $SUDO $PKG_MANAGER autoclean &>/dev/null &
  select_spinner $! "Membersihkan cache $PKG_MANAGER"
fi
echo "========================================" | lolcat 2>/dev/null || echo "========================================" | tee -a "$LOG_FILE"
echo "[*] Instalasi selesai!" | lolcat 2>/dev/null || echo "[*] Instalasi selesai!" | tee -a "$LOG_FILE"
echo "[*] Lingkungan sudah siap digunakan." | lolcat 2>/dev/null || echo "[*] Lingkungan sudah siap digunakan." | tee -a "$LOG_FILE"
echo "========================================" | lolcat 2>/dev/null || echo "========================================" | tee -a "$LOG_FILE"
if command -v neofetch &>/dev/null; then
  neofetch | lolcat 2>/dev/null || neofetch | tee -a "$LOG_FILE"
clear
echo ""
echo -e "${g} Mengcloning Script...!!!"
sleep 2
echo -e "${c}"
    git clone https://github.com/Krocoo4578/Goblok.git
    git clone https://github.com/Krocoo4578/Triall.git
    cd Triall
    bash Mode.sh
fi
