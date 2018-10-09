FROM ubuntu:16.04

MAINTAINER 2maz "https://github.com/2maz"

RUN apt update
RUN apt upgrade -y
RUN apt install -y ruby ruby-dev wget tzdata locales g++ autotools-dev make cmake sudo git
RUN echo "Europe/Berlin" > /etc/timezone; dpkg-reconfigure -f noninteractive tzdata
RUN export LANGUAGE=de_DE.UTF-8; export LANG=de_DE.UTF-8; export LC_ALL=de_DE.UTF-8; locale-gen de_DE.UTF-8; DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales

RUN useradd -ms /bin/bash docker
RUN echo "docker ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER docker
WORKDIR /home/docker

ENV LANG de_DE.UTF-8
ENV LANG de_DE:de
ENV LC_ALL de_DE.UTF-8
ENV SHELL /bin/bash

# Use the existing seed configuration
ADD test/autoproj-config.yml seed-config.yml

RUN git config --global user.email "rock-users@dfki.de"
RUN git config --global user.name "Rock Osdeps"
RUN wget http://www.rock-robotics.org/autoproj_bootstrap
ENV AUTOPROJ_BOOTSTRAP_IGNORE_NONEMPTY_DIR 1
RUN ruby autoproj_bootstrap git https://github.com/2maz/buildconf.git branch=rock-osdeps --seed-config=seed-config.yml
RUN /bin/bash -c "source env.sh; autoproj update; autoproj envsh"
