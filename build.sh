sudo apt update -y
sudo apt upgrade -y
sudo apt install -y python3 python3-pip
sudo apt install -y bc ffmpeg docker.io npm
sudo usermod -aG docker bladway
npm install
pip3 install -r python-requirements.txt
docker pull elgalu/selenium:latest
docker network create bbb

