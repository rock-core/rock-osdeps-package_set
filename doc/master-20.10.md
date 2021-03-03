# Release notes: master-20.10

The release named master-20.10 comes only with minor updates and support 
the same features as master-20.10 regarding the package separation and
environment generation.

# Run without autoproj via shipped env.sh
To run the release without autoproj:
```
echo "deb [arch=amd64 trusted=yes] https://rock.hb.dfki.de/rock-releases/master-20.10 bionic main" | sudo tee /etc/apt/sources.list.d/rock-master-20.10.list
echo "deb-src [arch=amd64 trusted=yes] https://rock.hb.dfki.de/rock-releases/master-20.10 bionic main" | sudo tee /etc/apt/sources.list.d/rock-master-20.10.list
wget -qO - https://rock.hb.dfki.de/rock-releases/rock-robotics.public.key | sudo apt-key add -
sudo apt-get update > /dev/null

sudo apt install rock-master-20.10-meta-full
source /opt/rock/master-20.10/rock-master-20.10-meta-full/env.sh

# You might have to restart your omniorb for the following command,
# just follow the instructions of the error message if there is one
rock-display
```
