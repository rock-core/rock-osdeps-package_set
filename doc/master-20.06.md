# Release notes: master-20.06

The release named master-20.06 comes with the following major changes:

- separate package directories, e.g., base/types will be found in
/opt/rock/master-20.06/rock-master-20.06-base-types
- an env.sh per package, e.g., /opt/rock/master-20.06/rock-master-20.06-base-types/env.sh
- a meta package for the full release: rock-master-20.06-meta-full
- yard documentation for all Ruby packages: just browse /opt/rock/master-20.06/share/doc/index.html

## New Features

### Package separation
Having separate package prefixes tries to mirror the effects of the Autoproj setting: Autoproj.config.separate_prefixes = true.
This might expose some inconsistencies in package setups and exposes wrong assumptions or missing dependency definition for including headers and linking directories.
For instance it breaks the assumption on a commonly shared installation folder, e.g., when multiple packages install into 'share' folder and expect it to be one location.

Hence, package maintainers should not rely on a shared folder, but base resource retrieval, e.g., on a customly set environment variable which adds the required search paths per package. Using pkg-config provides a further option.

### Run Rock without autoproj via shipped env.sh
As a major change compared to previous releases you can now run rock without autoproj:
```
echo "deb [arch=amd64 trusted=yes] http://rock.hb.dfki.de/rock-releases/master-20.06 bionic main" | sudo tee /etc/apt/sources.list.d/rock-master-20.06.list
echo "deb-src [arch=amd64 trusted=yes] http://rock.hb.dfki.de/rock-releases/master-20.06 bionic main" | sudo tee /etc/apt/sources.list.d/rock-master-20.06.list
wget -qO - http://rock.hb.dfki.de/rock-releases/rock-robotics.public.key | sudo apt-key add -
sudo apt-get update > /dev/null

sudo apt install rock-master-20.06-meta-full
source /opt/rock/master-20.06/rock-master-20.06-meta-full/env.sh
```
