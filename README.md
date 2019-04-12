## aptplatforms/oraclelinux-python

### Docker Image

[![][microbadger-img]](https://microbadger.com/images/aptplatforms/oraclelinux-python:latest)
[![][shields-automated-img]](https://hub.docker.com/r/aptplatforms/oraclelinux-python/builds/)
[![][shields-pulls-img]](https://hub.docker.com/r/aptplatforms/oraclelinux-python/)
[![][shields-stars-img]](https://hub.docker.com/r/aptplatforms/oraclelinux-python/)

[Oracle Linux] 7-slim with [Python 3.7.3] and [oracle-instantclient-18.5-basiclite]

This image can be used directly but is most useful when used in a `FROM`
statement in your own Dockerfile. [Python] and [pip] are installed, but you
will need to include [cx_Oracle] in your requirements specifications yourself.

### Included / Updated Packages

#### SQLite 3.27.2

- Installed in `/usr/local`

- Django-2.2 requires SQLite-3.8.3 or above. Oracle Linux 7 only has 3.7.17.
This inclusion allows use of Django-2.2 with cx_Oracle and Python 3.7. You're
welcome.

#### Python 3.7.3

- Installed in `/usr/local`
- Built with LTO and linked to SQLite 3.27.2

#### Oracle Instant Client 18.5 Basic Lite

- Installed in `/usr/lib/oracle/18.5/client64`

### Docker Tags

- 7-slim-py3.7.3-oic18.5
- base / builder / latest
  - Cache images used in the multi-stage build. Useful if you're hacking on the
image.

[Oracle Linux]: https://hub.docker.com/_/oraclelinux/
[oracle-instantclient-18.5-basiclite]: https://yum.oracle.com/repo/OracleLinux/OL7/oracle/instantclient/x86_64/index.html
[Python]: https://www.python.org/
[Python 3.7.3]: https://docs.python.org/3/whatsnew/changelog.html#python-3-7-3-final
[pip]: https://pip.pypa.io/en/stable/
[cx_Oracle]: https://oracle.github.io/python-cx_Oracle/
[microbadger-img]: https://images.microbadger.com/badges/image/aptplatforms/oraclelinux-python:latest.svg
[shields-automated-img]: https://img.shields.io/docker/automated/aptplatforms/oraclelinux-python.svg
[shields-pulls-img]: https://img.shields.io/docker/pulls/aptplatforms/oraclelinux-python.svg
[shields-stars-img]: https://img.shields.io/docker/stars/aptplatforms/oraclelinux-python.svg
