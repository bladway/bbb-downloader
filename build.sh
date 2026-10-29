# ubuntu
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y vdpauinfo
sudo apt-get install -y python3 python3-pip
sudo apt-get install -y bc ffmpeg docker.io npm
sudo apt-get install -y python3-requests python3-numpy python3-progressbar python3-wheel
sudo add-apt-repository --yes ppa:graphics-drivers/ppa
sudo apt-get update -y
sudo systemctl disable systemd-timesyncd
sudo systemctl stop systemd-timesyncd
user=$(whoami)
sudo usermod -aG docker $user
export PATH="$PATH:/home/$user/.local/bin"
npm install
python3 -m venv bbb-downloader_venv
source bbb-downloader_venv/bin/activate
pip3 install -r python-requirements.txt
deactivate
docker pull elgalu/selenium:latest
docker network create bbb

# archlinux
sudo pacman -Syu --noconfirm --needed vdpauinfo
sudo pacman -Syu --noconfirm --needed bc npm
python3 -m venv .venv
. .venv/bin/activate
pip install -r python-requirements.txt
sudo systemctl disable --now systemd-timesyncd.service
npm install
docker pull elgalu/selenium:latest
docker network create bbb

# build new image
docker build --pull=false \
    --build-arg FIREFOX_VERSION=158.0.1 \
    --build-arg GECKODRIVER_VERSION=0.37.1 \
    -t elgalu/selenium:bbb-firefox158 \
    .
