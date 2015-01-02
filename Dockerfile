# This is a first stab at writing a Koha Git Dockerfile.
#
# Plan of Action:
#
# Install all Koha dependencies and provide an environment ready for
# koha-dev install.
# Idea is as follows:
# - user imports this Dockerfile
# - runs it, mounting their koha repo at the volume mount point
# - runs a dev-install
# - runs web installer
# - ready to go.
#
# We can set installation defaults with environment variables and then
# simply default during Makefile.PL.

FROM localhost:5000/koha-base
MAINTAINER Alex Sassmannshausen <alex.sassmannshausen@ptfs-europe.com>

# Koha Instance and Dev User Config
ENV user koha-dev

USER ${user}
WORKDIR /home/${user}
RUN git clone https://github.com/Koha-Community/Koha.git
WORKDIR /home/${user}/Koha
RUN git remote add ptfs https://github.com/ptfs-europe/koha.git
COPY aux/koha-dev/ /home/${user}/koha-dev/
RUN perl Makefile.PL --prev-install-log /home/${user}/koha-dev/misc/koha-install-log
RUN make && make install
COPY aux/koha-httpd.conf /home/${user}/koha-dev/etc/koha-httpd.conf
COPY aux/koha-zebra-ctl.sh /home/${user}/koha-dev/bin/koha-zebra-ctl.sh
COPY aux/koha-index-daemon-ctl.sh /home/${user}/koha-dev/bin/koha-index-daemon-ctl.sh
USER root

RUN ln -s /home/${user}/koha-dev/etc/koha-httpd.conf \
    /etc/apache2/sites-available/koha
RUN ln -s /home/${user}/koha-dev/bin/koha-zebra-ctl.sh \
    /etc/init.d/koha-zebra-ctl.sh
RUN ln -s /home/${user}/koha-dev/bin/koha-index-daemon-ctl.sh \
    /etc/init.d/koha-index-daemon-ctl.sh

ENV HOME /root
WORKDIR /root
COPY aux/docker-entrypoint.sh /root/entrypoint.sh
ENTRYPOINT ["/root/entrypoint.sh"]
