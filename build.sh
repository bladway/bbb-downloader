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

