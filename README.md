# Package set: rock-osdeps
[![Build Status](https://travis-ci.org/rock-core/rock-osdeps-package_set.svg?brach=master)](https:///travis-ci.org/rock-core/rock-osdeps-package_set)


* https://github.com/rock-core/rock-osdeps-package_set

Allows you to activate the use of Rock Debian package releases in an autoproj
installation.

## Supported Platforms:
The following table lists the distribution and architecture combinations which
are currently supported by existing releases.
Currently releases are named after the (dominating) branch name 'master' plus
the year and month in YY.mm format.
The table below implies that at least base/orogen/types are available for this platform.

| Distribution  | [master-20.10](doc/master-20.10.md) | [master-20.06](doc/master-20.06.md) | master-20.01 |    master-19.06  |     master-18.09 |     master-18.01     |
|---------------|--------------|--------------------|------------------|------------------|----------------------|-----------|
|Ubuntu 16.04   |              |             | amd64        | amd64            |    amd64         | amd64                |
|Ubuntu 18.04   | amd64,arm64 |amd64,arm64  | amd64        | amd64            |    amd64         ||
|Ubuntu 20.04   |              |             |              |                  |                  ||
|Debian Jessie  |              |             |              | armel,armhf      |                  ||
|Debian Stretch |              |             |              | amd64            |    amd64         ||
|Debian Buster  | amd64,arm64  |amd64,arm64  | amd64,arm64  | amd64            |                  ||

Not all packages of rock-core and rock package sets could be built for all releases.
The details on which packages are available for each platform can be extracted
from the files in the subfolder in data/*release*_*architecture*.yml after
activation of the release. The file can be simply read as an autoproj osdeps file.


## How to use an Rock Debian package release

### PPA-Style usage (from master-20.06 onwards)

Add the package repository (verify URLs by information provided in
data/releases.yml):
```
    wget -qO - https://rock.hb.dfki.de/rock-releases/rock-robotics.public.key | sudo apt-key add -
    echo 'deb [arch=amd64 trusted=yes] https://rock.hb.dfki.de/rock-releases/master-20.06 bionic main' | sudo tee /etc/apt/sources.list.d/rock-master-20.06.list
    sudo apt update
```

To verify the key:
```
pub   rsa4096 2019-04-16 [SC]
      50A81F9A03A9D861A2C8CA48AE1C10781C3E5ED9
uid           Rock Developers (Maintainers of the Robot Construction Kit aka Rock) <rock-dev@dfki.de>
```

Now, you can either choose to install individual packages, such as base-types
with:
```
    sudo apt install rock-master-20.06-base-types
```

or install all available Rock packages for your platform

```
    sudo apt install rock-master-20.06-meta-full
```

To use the release, you will still have to update your
environmental settings, e.g., when using the full release this is straight
forward:

```
    source /opt/rock/master-20.06/rock-master-20.06-meta-full/env.sh
```

Activation of individual packages is also possible, but currently somewhat
inconvenient see Section "Known Issues -> 2."

### As part of an Autoproj-based workspace
Either start with a fresh bootstrap:

```
    sudo apt install ruby ruby-dev wget
    wget http://www.rock-robotics.org/autoproj...
    ruby autoproj_bootstrap
```
If you want to use an already defined build configuration then replace the last step with something like:

```
    ruby autoproj_bootstrap git git://github.com/yourownproject/yours...
```
or remove the install folder in order to get rid of old packages.

If a release has been created with default settings all its Debian Packages
install their files into /opt/rock/release-name.
To activate Debian packages for your autoproj workspace:

adapt the autoproj/manifest to contain only the packages in the layout that you require as source packages. However, the layout section should not be empty, e.g. to bootstrap all precompiled packages of the rock-core package set add:

```
    layout:
    - rock.core

```

After the package_sets that you would require for a normal bootstrap, you
require to include this package set that contains the overrides for the Rock releases.
The package set contains the required osdeps definition and dynamically
generates the rock-osdeps.osdeps file, based on your current settings.
Additionally it create the required setup of environment variables through its
init.rb.
Hence, a minimal package set using the Rock Debian Package integration could look like the following:

```
    package_sets:
    - github: rock-core/package_set
    - github: rock-core/rock-osdeps-package_set
    layout:
    - rock.core
```

After adding the package set use autoproj as usual:

```
    source env.sh
    autoproj update
```

Follow the questions for configuration and select a release for the Debian packages.
Finally start a new shell, reload the env.sh and call amake.
This should finally install all required Debian packages and remaining required packages, which might have not been packaged.

### Switching to the test (or other custom) branches

New releases are prepare such that they can activated via switching to the
package_set's 'test' branch.
You can do this by changing the package_set definition in the autoproj/manifest
file as follows:

```
    package_sets:
    - rock-osdeps:
      type: git
      url: git@github.com:rock-core/rock-osdeps-package_set.git
      branch: test
```

### Features

#### Blacklisting of packages
In order to enforce the usage of a source package in a workspace create a file
autoproj/deb_blacklist.yml containing the name of the particular package. This
will disable automatically the use of this debian package and all that depend on
that package, e.g., to disable the orogen package (which is aliased by autoproj as tools/orogen), base/types and all packages that start with simulation/ create a deb_blacklist.yml with the following content:

```
    ---
    - base/types
    - ^orogen$
    - simulation/.*
```

You will be informed about the disabled packages:

Triggered regeneration of rock-osdeps.osdeps: /opt/workspace/rock_autoproj_v2/.autoproj/remotes git_git_github_com_2maz_rock_osdeps_git/lib/../rock-osdeps.osdeps, blacklisted packages: ["base/types"]
Disabling osdeps: ["base/types", "tools/service_discovery", "tools/pocolog_cpp", ...

#### Identify the version of package

All packages are versioned according to their last (official) commit date, e.g., 0.*date-of-last-commit*


```
    $> dpkg -l rock-master-18.09-base-cmake
    Desired=Unknown/Install/Remove/Purge/Hold
    | Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
    |/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
    ||/ Name                                          Version                     Architecture                Description
    +++-=============================================-===========================-===========================-==============================
    ii  rock-master-18.09-base-cmake                  0.20170821-1~xenial         amd64                       CMake find scripts and macros
```
To identify which exact version of a package is in use you can check the changelog of the package:
```
    $> zless /usr/share/doc/rock-master-18.09-base-cmake/changelog.Debian.gz
    rock-master-18.09-base-cmake (0.20170821-1~xenial) unstable; urgency=low

      * Package automatically built using autoproj-package debian
      * repository: github:/rock-core/base-cmake.git
      * branch: refs/heads/master
      * commit: a1703a0b30dcc0380a5be147ea2ee1ca89fa25b3
      * tag:

     -- Packaging Daemon <rock-dev@dfki.de>  Mon, 08 Oct 2018 10:39:43 +0200
```

#### Browse the documentation

Just open /opt/rock/master-XX.XX/share/doc/index.html to see the doxygen / rdoc/
yard documentation for all installed packages of the corresponding release.

Note that till master-20.01 the ruby documentation generation did use rdoc (due
to a bug).
master-20.06 starts to use yard generated documentation.

### Known Issues
1.  If you get a message like
    ```
        error loading "/opt/rock/master-18.01/lib/ruby/vendor_ruby/hoe/yard.rb": yard is not part of the bundle. Add it to Gemfile.. skipping...
    ```

    Then add the following to install/gems/Gemfile (in the corresponding autoproj installation)

    ```
       gem 'yard'
    ```

    The error should not be encountered with 'master-18.09', where yard is also provided as Rock package. This is not the case for master-18.01.


2.  For PPA-style usage (master-20.06 onwards):
    if you only want to source an individual package you currently will have to generate your
    own env.sh script, since the env.sh setup of a package does only cover the
    package itself and not its dependencies. Hence to identify the env.sh file of
    the dependencies, e.g., here for master-20.06 and base/types you can do the
    following:

```
        $>apt-cache depends rock-master-20.06-base-types | grep rock | grep Depends | cut -d' ' -f4 | xargs -I{} echo ". /opt/rock/master-20.06/{}/env.sh"
        . /opt/rock/master-20.06/rock-master-20.06-base-cmake/env.sh
        . /opt/rock/master-20.06/rock-master-20.06-base-logging/env.sh
        . /opt/rock/master-20.06/rock-master-20.06-external-sisl/env.sh
        . /opt/rock/master-20.06/rock-master-20.06-gui-vizkit3d/env.sh
        . /opt/rock/master-20.06/rock-master-20.06-ruby-rice/env.sh
```

        Also add the env.sh of you package to your custom setup.sh script:

```
        . /opt/rock/master-20.06/rock-master-20.06-base-types/env.sh
```



## References and Publications
Please reference the following publication when referring to the
binary packaging of Rock:

```
    Binary software packaging for the Robot Construction Kit
    Thomas M. Roehr, Pierre Willenbrock
    In Proceedings of the 14th International Symposium on Artificial Intelligence, (iSAIRAS-2018), 04.6.-06.6.2018, Madrid, ESA, Jun/2018.
```

## Merge Request and Issue Tracking

Github will be used for pull requests and issue tracking: https://github.com/rock-core/rock-osdeps-package_set

## License

This software is distributed under the [New/3-clause BSD license](https://opensource.org/licenses/BSD-3-Clause)

## Copyright

Copyright (c) 2014-2021, DFKI GmbH Robotics Innovation Center
