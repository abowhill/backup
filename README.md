What is this?
=============

This is a `Ruby` script that helps simplify the process of making selective backups on `UNIX-like` systems. A selective backup is one in which files and directories are selected according to the user's personal criteria of what is worth preserving and archiving. Selective backups are a fraction of the size of a full system dump, and are intended to preserve customized work.

Features
--------

* _Decoupled._ This script only prints pathnames to `STDOUT`. This data can be piped to any utility, for any purpose, but the script was made with archving and `pax` in mind.

* The ability to specify a list of files or whole directories to scan for pathnames. This is called the __backup specification__.

* The ability to apply a single backup specification to multiple roots, such as those found on a system hosting `FreeBSD` jails. This is called the __root list__.

* A global exclusion list which can be set to ignore specified directories relative to the given roots. Roots themselves are automatically added to this list. This is called the __exclusion list__.


Input and Output
----------------
On input, this script reads sections and directives in a configuration file created by the user. The full path to this file is the only command-line parameter. Based on the contents of the configuration file, a list of full pathnames is sent to `STDOUT` suitable for piping to an archive utility such as `pax`.

Description
------------

All user-supplied data is provided in the configuration file. The file can have any name, and can reside anywhere on the system. Internally, the confugration file is laid out somewhat similarly to an `.ini` file but with some required fields and syntax.

The configuration file has five types of entries: `[[section]]`, `[/directory]`, `file`, `#comment` and `blank`. All entries are kept one-per-line. `Blank` lines and `#comment` lines are ignored, and may appear freely between other entries.

`[[section]]` entries
-------------------

There are three required `[[section]]` entries containing fixed keywords. Section entries are enclosed in double-brackets `[[ ]]` with a keyword in the middle.

_Example A._ (this configuration will do nothing)

	[[roots]]

	[[backups]]

	[[exclusions]]

### `[[roots]]` tag

`[[roots]]` marks the start of the root list. The root list is a list of directories that the backup specification will be applied-to. One or more `[/directory]` entries are listed below the `[[roots]]` tag.

Define two roots to apply the backup specification: the host (`/`) and a jail (`/usr/jails/192.1680.99`). Does nothing when run.

_Example B:_

	[[roots]
	[/]
	[/usr/jails/192.168.0.99]

	[[backups]]

	[[exclusions]]

### `[[backups]]` tag

`[[backups]]` marks the start of the backup specification. This must contain one or more file and/or `[/directory]` entries.

_Example C._

Define a single file in the specification: `/etc/rc.conf`, and apply it to two roots from Example B. above. Full pathnames to this file under each root will be displayed on output if they exist:

	[[roots]]
	[/]
	[/usr/jails/192.168.0.99]

	[[backups]]

	[/etc]
	rc.conf

	[[exclusions]]

Which produces on stdout:

	/etc/rc.conf
	/usr/jails/192.168.0.99/etc/rc.conf

Note that directories always appear enclosed in single-brackets, and filenames have no enclosure. To define more files to be scanned under `/etc`, we can simply add their names under the `[/etc]` list:

_Example D._

	[[roots]]
	[/]
	[/usr/jails/192.168.0.99]

	[[backups]]

	[/etc]
	rc.conf
	resolv.conf
	make.conf
	groups
	passwd
	fstab

	[[exclusions]]

Which produces on stdout:

	/etc/rc.conf
	/etc/resolv.conf
	/etc/make.conf
	/etc/passwd
	/etc/fstab
	/usr/jails/192.168.0.99/etc/rc.conf
	/usr/jails/192.168.0.99/etc/resolv.conf
	/usr/jails/192.168.0.99/etc/make.conf
	/usr/jails/192.168.0.99/etc/passwd

If you want to scan an entire directory for a list of files thereunder, just specify the `[/directory]` without any list of files. If the script sees this type of entry, it will scan blindly for everything under the directory. 

For example, suppose we want to add all the files under `/etc/ssl`, which at the moment are only two, but could grow over time:

_Example E._

	[[roots]]
	[/]
	[/usr/jails/192.168.0.99]

	[[backups]]

	[/etc]
	rc.conf
	resolv.conf
	make.conf
	groups
	passwd
	fstab

	# scan this directory for all files under it
	[/etc/ssl]

	[[exclusions]]

Which produces on stdout:

	/etc/rc.conf
	/etc/resolv.conf
	/etc/make.conf
	/etc/passwd
	/etc/fstab
	/etc/ssl
	/etc/ssl/cert.pem
	/etc/ssl/openssl.cnf
	/usr/jails/192.168.0.49/etc/rc.conf
	/usr/jails/192.168.0.49/etc/resolv.conf
	/usr/jails/192.168.0.49/etc/make.conf
	/usr/jails/192.168.0.49/etc/passwd
	/usr/jails/192.168.0.49/etc/ssl
	/usr/jails/192.168.0.49/etc/ssl/cert.pem
	/usr/jails/192.168.0.49/etc/ssl/openssl.cnf

So, if a `[/directory]` entry is on a line by itelf, a blind-scan is done. If a `[/directory]` entry appears with a following list of files, only those files are scanned.

### `[[exclusions]]` tag

The `[[exclusions]]` tag marks the start of the `exclusion list`. This list can contain zero or more `[/directory]` entries. Excluded directories apply only to blind scans of directories in the backup spefication. They are intended to weed-out large numbers of unwanted files in a scan of a parent directory.

Additionally, all directories listed in the `root specification` will also be skipped if they are found.

For example, suppose I want to backup everything under `/root`, but want to ignore an large subdirectory of unwanted files called `/root/sources-123-extracted` :

_Example F._

	[/]
	[/usr/jails/192.168.0.99]

	[[backups]]

	[/etc]
	rc.conf
	resolv.conf
	make.conf
	groups
	passwd
	fstab

	[/etc/ssl]

	# scan /root dir
	[/root]


	[[exclusions]]

	# ignore unwanted directory
	[/root/sources-123-extracted]

This would allow all the dot-files under root to be listed to STDOUT, but would ignore the unwanted directory entirely.


Archiving with pax
-----------------

`pax` is the utility that was created to bridge the gap between `cpio` and `tar`. It creates uncompressed archives, which can be inspected and compressed by `gzip`.

Before starting, it's worth noting that `pax` will try to archive the archive it is creating if you are doing this operation inside one of the areas you are scanning. This results in an error. So it's best to put the archive somewhere outside the scanning area.

Additionally, running as `root` will prevent missing files that cannot be read as the current user.

To archive to `pax`, use:

	# ruby backup.rb backup.conf | pax -w -d -f /tmp/archive.pax

Then to compress:

	# gzip archive.pax


Unarchiving is just the reverse, but will restore all files in the archive by **OVERWRITING THEM** on the system:

	# gunzip archive.pax.gz

	# pax -d -r -v -pe -f archive.pax


Caveats
-------

This script has only been lightly tested, and is still under development. I've tried my best to describe its behavior, but there are probably hidden behaviors I am unaware of. Therefore I accept no liability in the use of this script, nor do I give any warranty for its use.

