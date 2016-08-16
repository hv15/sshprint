SSHPrint
========

This is a small Perl script I created to quickly print something to a printer
connected to a remote network. Principally, the script adds some extra stuff
around

```sh
ssh $USER@$REMOTEHOST "lpr -P $PRINTER" < "$DOCUMENT"
```

such as providing a list of available printers (using `lpstat -p`) as well as
using a configuration files to setup some things (username and server
address for one as well as store a list of printers for quick and easy
selection). Additionally printer options (`lpr -o ...`) can be specified as
well as the number copies wanted.

`sshprint` can now interact with multiple servers, each with its own
configurations. A user can specify which one they want through both a command
line argument or config key.

Manual
------

In order to use the script, you need to have [Perl](http://www.perl.org/) and
OpenSSH `ssh`. Additionally, the remote server needs to have the `lpr` and
`lpstat` programs installed and access to at least one printer.

### Installation

*THis section is going to be updated ASAP*

For those running on ArchLinux, I've created a PKGBUILD script which you can
use to generate the package, or if you use `yaourt`/`pacaur`, you can get the
package straight from the [AUR](https://aur.archlinux.org/packages/sshprint/).

### Config

`sshprint` supports several config files, all of which are located in
`~/.config/sshprint/` by default. Any setup of `sshprint` needs to have at
least two config files. The main config file to specify some\* default values
(called `config`) and a server config file to specify server related options.
The config files support the following keys:

#### Keys for `config` file

| Key        | Meaning and Use                                                                                                      |
|------------|----------------------------------------------------------------------------------------------------------------------|
| `DEFAULTS` | This is the name of the server config file that `sshprint` will use if none is given by command line (**REQUIRED**)  |

#### Keys for Server config file

| Key         | Meaning and Use                                                                |
|-------------|--------------------------------------------------------------------------------|
| `USER`      | The username of the account  on the remote server (**REQUIRED**)               |
| `SERVER`    | The address of the remote server (**REQUIRED**)                                |
| `PRINTERS`  | An array of the names of printer that can be used (*generated at initial run*) |
| `FAVORITEP` | An array of the top three last used printers (*generated at each run*)         |

An example of a typical server config file is given below:

```sh
USER="remote server user account"
SERVER="URL to server"
PRINTERS= # Can contain a list of printer names, e.g. ( p1 p2 office1 )
FAVORITEP= # list of the 3 most used printers, e.g. ( p1 p2 p3 )
```

**These file are not initialised or created by the script at first use, the
user needs to create it themselves**. I have now provided an example of the
config file as part of this repo, it should be enough to get started. The
config file is loaded at each call of `sshprint` and the variables are sourced
and used directly in the script. *No checks are performed to ensure sane
formating or validity of keys*.

### Usage

```
Usage: sshprint [OPTIONS...] FILE
   or: sshprint [OPTIONS...] --file FILE

Options:
  -h, --help                  Print this help message and exit
  -v, --verbose               Show verbose output, specifiy multiple
                               times to increase verbosity
  -V, --version               Print version and exit
  --refresh-printers          Refresh list of printers in config  
  --list-printers             Print a list of printers
  --list-servers              Print a list of servers
  --server=SERVER             Server to connect to and print from
  --file=FILE, FILE           File to be printed

Options passed to `lpr':
  -P printer_name             Specify printer to print to
  -n, -#, --copies=NUM        Specify number of copies
  -o, --option option[=value] Set printer option(s)

Extra:
  If verbosity is greater than 3 (i.e. `-vvv') the script will no longer
  print the specified file, instead it will print out detailed debug
  information such as options being passed over SSH to lpr.
```

Further Work
------------

A few extensions I'd like to add:

* improve existing server config files to include meta-data about printers
  like last time the user used them, whether their colour or mono, etc.)
* an easy setup script to generate all the config in one go as part of the
  installation/setup process

Warranty and License
--------------------

Warranty: none given... plus I can guarantee that something is amiss with my
script (issue reports welcome!). This script is licensed under the MIT
license.
