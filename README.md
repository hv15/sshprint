SSHprint
========

This is a small ZSH script I created to quickly print something to a printer
connected to a remote network. Principally, the script adds some extra stuff
around

```sh
ssh $USER@$REMOTEHOST "lpr -P $PRINTER $DOCUMENT"
```

such as providing a list of available printers (using `lpstat -a`) as well as
using a configuration file to setup some things nice (username and server
address for one).

Usage
-----

```sh
Usage: sshprint [-h | --help] [-V | --version] [-P printer_name] {--file} file
Options:
  -h, --help            Print this help message and exit
  -V, --version         Print version and exit
  -P=<printer_name>     Specify <printer_name> to print to
  --file=<file>, <file> File to be printed
```

Further Work
------------

There are a few problems with how the script works. For one, we need to connect
to the remote server multiple time in order to: A. get the list of printers,
and B. send the document to the printer. If you don't use SSH keys to access
the server, you'll need to login multiple time (which is obviously a pain).

A current idea I had was to create a more sophisticated config file with host
specific options that could be altered by `sshprint`. An example would be the
storing of printers, with periodic updates.

Warranty and License
--------------------

Warranty, none given...plus I can guarantee that something is amiss with my
script (issue reports welcome!). This script is licensed under the MIT license.
