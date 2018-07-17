# Package set: rock-osdeps
[![Build Status](https://travis-ci.org/rock-core/rock-osdeps-package_set.svg?brach=master)](https:///travis-ci.org/rock-core/rock-osdeps-package_set)


* https://github.com/rock-core/rock-osdeps-package_set

Allows you to activate the use of Rock Debian package releases in an autoproj
installation

## How to use an Apaka release in combination with Rock
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
install their files into /opt/rock/release-name and now to activate debian
packages for your autoproj workspace:

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

### Features

* in order to enforce the usage of a source package in a workspace create a file autoproj/deb_blacklist.yml containing the name of the particular package. This will disable automatically the use of this debian package and all that depend on that package, e.g., to disable base/types and all packages that start with simulation/ create a deb_blacklist.yml with the following content:

```
    ---
    - base/types
    - simulation/*
```

You will be informed about the disabled packages:

Triggered regeneration of rock-osdeps.osdeps: /opt/workspace/rock_autoproj_v2/.autoproj/remotes git_git_github_com_2maz_rock_osdeps_git/lib/../rock-osdeps.osdeps, blacklisted packages: ["base/types"]
Disabling osdeps: ["base/types", "tools/service_discovery", "tools/pocolog_cpp", ...

### Known Issues
1.  If you get a message like
    ```
        error loading "/opt/rock/master-18.01/lib/ruby/vendor_ruby/hoe/yard.rb": yard is not part of the bundle. Add it to Gemfile.. skipping...
    ```

    Then add the following to install/gems/Gemfile (in the corresponding autoproj installation)
    ```
       gem 'yard'
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

(c) Copyright 2014-2018, DFKI GmbH Robotics Innovation Center
