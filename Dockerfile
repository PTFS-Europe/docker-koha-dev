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

FROM atheia/koha-base:v2
MAINTAINER Alex Sassmannshausen <alex.sassmannshausen@ptfs-europe.com>

# Koha Instance and Dev User Config
ENV user koha

# Create the git checkout (with ptfs remote).
USER ${user}
WORKDIR /home/${user}
RUN git clone https://github.com/Koha-Community/Koha.git kohaclone
WORKDIR /home/${user}/kohaclone
RUN git remote add ptfs https://github.com/ptfs-europe/koha.git

# Install Koha with predefined defaults
COPY aux/koha-dev/ /home/${user}/koha-dev/
USER root
RUN chown -R ${user}:${user} /home/${user}/koha-dev
USER ${user}
RUN perl Makefile.PL --prev-install-log \
    /home/${user}/koha-dev/misc/koha-install-log
RUN make && make install
RUN echo "export KOHA_CONF='/home/${user}/koha-dev/etc/koha-conf.xml'" \
    >> /home/${user}/.bashrc
RUN echo "export PERL5LIB='/home/${user}/kohaclone'" \
    >> /home/${user}/.bashrc

# Setup apache configuration
USER root
COPY aux/koha-httpd.conf /home/${user}/koha-dev/etc/koha-httpd.conf
RUN chown ${user}:${user}                        \
    /home/${user}/koha-dev/etc/koha-httpd.conf
RUN ln -s /home/${user}/koha-dev/etc/koha-httpd.conf \
    /etc/apache2/sites-available/koha
RUN a2dissite default
RUN a2ensite koha

# Install our service scripts.
RUN ln -s /home/${user}/koha-dev/bin/koha-zebra-ctl.sh \
    /etc/init.d/koha-zebra-ctl.sh
RUN ln -s /home/${user}/koha-dev/bin/koha-index-daemon-ctl.sh \
    /etc/init.d/koha-index-daemon-ctl.sh

# Prep for exit
ENV HOME /root
WORKDIR /root
COPY aux/docker-entrypoint.sh /root/entrypoint.sh
ENTRYPOINT ["/root/entrypoint.sh"]
