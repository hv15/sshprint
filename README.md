SSHprint
========

This is a small *ZSH* script I created to quickly print something to a printer
connected to a remote network. Principally, the script adds some extra stuff
around

```sh
ssh $USER@$REMOTEHOST "lpr -P $PRINTER" < "$DOCUMENT"
```

such as providing a list of available printers (using `lpstat -a`) as well as
using a configuration file to setup some things nice (username and server
address for one as well as store a list of printers for quick an easy
selection). Additionally printer options (`lpr -o ...`) can be specified.

Manual
------

In order to use the script, you need to have [ZSH](http://www.zsh.org/) and an
SSH client (e.g. OpenSSH `ssh`). Additionally, the remote server needs to have
the `lpr` and `lpstat` programs installed and access to at least one printer.

### Installation

As with any script, place it somewhere within your `$PATH` and make sure that
it is executable.

For those running on ArchLinux, I've created a PKGBUILD script which you can
use to generate the package, or if you use `yaourt`/`pacaur`, you can get the
package straight from the [AUR](https://aur.archlinux.org/packages/sshprint/).

### Config

`sshprint` supports a config file (default location:
`~/.config/sshprint/config`) that has the format:

```sh
USER="remote server user account"
SERVER="URL to server"
PRINTERS=() # Can contain a list of printer names, e.g. ( p1 p2 office1 )
FAVORITEP=() # list of the 3 most used printers
```

**The file is not initialised or created by the script at first use, the user
needs to create it themselves**. I have now provided an example of the config
file as part of this repo, it should be enough to get started. The config file
is loaded at each call of `sshprint` and the variables are sourced and used
directly in the script. *No checks are performed to ensure sane formating or
validity of values*.

### Usage

```
Usage: sshprint [OPTIONS...] FILE
   or: sshprint [OPTIONS...] --file FILE

Options:
  -h, --help              Print this help message and exit
  -V, --version           Print version and exit
  -r, --refresh-printers  Refresh list of printers in config  
  -p, --list-printers     Print a list of printers
  --file=FILE, FILE       File to be printed

Options passed to `lpr':
  -P <printer_name>       Specify <printer_name> to print to
  -n copies               Specify number of copies
  -o option[=value],...   Set printer option(s)
```

Further Work
------------

A few extentions I'd like to add:

* Make the configuration more sophisticated, allowing for more hosts to be
  added with individual configurations.

Warranty and License
--------------------

Warranty: none given...plus I can guarantee that something is amiss with my
script (issue reports welcome!). This script is licensed under the MIT
license.
