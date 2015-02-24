SSHprint
========

This is a small *ZSH* script I created to quickly print something to a printer
connected to a remote network. Principally, the script adds some extra stuff
around

```sh
ssh $USER@$REMOTEHOST "lpr -P $PRINTER $DOCUMENT"
```

such as providing a list of available printers (using `lpstat -a`) as well as
using a configuration file to setup some things nice (username and server
address for one as well as store a list of printers for quick an easy
selection).

Manual
------

In order to use the script, you need to have [ZSH](http://www.zsh.org/) and an
SSH client (e.g. OpenSSH `ssh`). Additionally, the remote server needs to have
the `lpr` and `lpstat` programs installed and access to at least one printer.

### Config

`sshprint` supports a config file (default location:
`~/.config/sshprint/config`) that has the format:

```sh
USER="remote server user account name"
SERVER="URL to server"
PRINTERS=() # Can contain a list of printer names, e.g. ( p1 p2 office1 )
DEFAULTP="name of default printer"
```

**The file is not initialised or created by the script at first use, the user
needs to create themselves**. The config file is loaded at each call of
`sshprint` and the variables are sourced and used directly in the script.
*No checks are performed to ensure sane formating or validity of values*.

### Usage

```
Usage: sshprint [-h | --help] [-V | --version] [-D | --set-default <printer_name>] [-r | --refresh-printers] [-p | --list-printers]  [-P <printer_name>] {--file} <file>
Options:
  -h, --help              Print this help message and exit
  -V, --version           Print version and exit
  -r, --refresh-printers  Refresh list of printers in config  
  -p, --list-printers     Print a list of printers
  -D=<printer_name>       Write default printer to config file
  -P=<printer_name>       Specify <printer_name> to print to
  --file=<file>, <file>   File to be printed
```

Further Work
------------

Make the configuration more sophisticated, allowing for more hosts to be added
with individual configurations.

Warranty and License
--------------------

Warranty: none given...plus I can guarantee that something is amiss with my
script (issue reports welcome!). This script is licensed under the MIT license.
