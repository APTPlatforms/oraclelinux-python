## aptplatforms/oraclelinux-python

### Docker Image

[![][microbadger-img]](https://microbadger.com/images/aptplatforms/oraclelinux-python:latest)
[![][shields-automated-img]](https://hub.docker.com/r/aptplatforms/oraclelinux-python/builds/)
[![][shields-pulls-img]](https://hub.docker.com/r/aptplatforms/oraclelinux-python/)
[![][shields-stars-img]](https://hub.docker.com/r/aptplatforms/oraclelinux-python/)

### Docker Tags

#### 7-slim-py3.7.3-oic18.5

[Oracle Linux] 7-slim with [Python 3.7.3] in `/usr/local` and [oracle-instantclient-18.5-basiclite] in `/usr/lib/oracle/18.5/client64/lib`

This image can be used directly but is most useful when used in a `FROM`
statement in your own Dockerfile. [Python] and [pip] are installed, but you
will need to include [cx_Oracle] in your requirements specifications yourself.

#### base / python-build / latest

Cache images used in the multi-stage build. Useful if you're hacking on the
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
