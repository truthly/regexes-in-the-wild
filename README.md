<h1 id="top"><code>regexes-in-the-wild</code></h1>

1. [What is it?](#what-is-it)

<h2 id="about">1. What is it?</h2>

☢️ This project is **expertimental** and **unreleased**. Nothing is working yet, this is **W**ork-**I**n-**P**rogress. Breaking changes can be made at any time.

This is a tool to build a dataset of regular expressions (regexes) found in the wild,
by crawling the front-pages for a list of websites, using a patched [Chromium],
which v8 Javascript engine has been modified to log all regexes and the text
strings on which they are applied, that actually get compiled and executed by the v8 regex engine.

The intended audience for this project is people working on regex engines,
in need of real-life test data, to test accuracy and performance.

[Chromium]: https://www.chromium.org/

```sh
cd $HOME
# clone this repo
git clone https://github.com/truthly/regexes-in-the-wild.git
# install postgresql
sudo apt-get -y dist-upgrade
sudo locale-gen "en_US.UTF-8"
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
sudo apt-get -y install gnupg
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql postgresql-server-dev-13 build-essential
sudo service postgresql start
sudo -u postgres createuser -s "$USER"
createdb -E UTF8 regexes
# install chromium
sudo apt-get install -y curl git htop man unzip vim wget python pkg-config
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH=$HOME/depot_tools:$PATH
mkdir chromium
cd chromium
fetch --no-history chromium
cd src
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | sudo debconf-set-selections
./build/install-build-deps.sh --no-prompt
(cd v8 && patch -p1 < $HOME/regexes-in-the-wild/chromium-v8-regexp-logger.patch)
mkdir -p out/Headless
echo 'import("//build/args/headless.gn")' > out/Headless/args.gn
echo 'is_debug = false' >> out/Headless/args.gn
gn gen out/Headless
ninja -C out/Headless headless_shell
sudo cp out/Headless/headless_shell /usr/local/bin/
# install puppeteer
sudo apt install npm
npm i puppeteer-core
npm i puppeteer-cluster
# put some domains in /home/regex/domains.txt, e.g.:
echo 'https://google.com' > /home/regex/domains.txt
echo 'https://apple.com' >> /home/regex/domains.txt
node fetch.js > /home/regex/regex.log
createdb regex
grep -E '^RegExp.*,.*,.*,' /home/regex/regex.log > /home/regex/regex.csv
psql -f regex.sql
psql -c "SELECT process_regex_log()"




