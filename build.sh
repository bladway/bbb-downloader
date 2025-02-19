sudo apt update -y
sudo apt upgrade -y
sudo apt install -y vdpauinfo
sudo apt install -y python3 python3-pip
sudo apt install -y bc ffmpeg docker.io npm
sudo add-apt-repository --yes ppa:graphics-drivers/ppa
sudo apt update -y
user=$(whoami)
sudo usermod -aG docker $user
exec su -l $user
export PATH="$PATH:/home/$user/.local/bin"
npm install
pip3 install -r python-requirements.txt
docker pull elgalu/selenium:latest
docker network create bbb

