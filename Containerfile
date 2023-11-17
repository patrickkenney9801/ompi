ARG BUILD_IMAGE=ubuntu:22.04
ARG RELEASE_IMAGE=ubuntu:22.04
FROM ${BUILD_IMAGE} AS build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update -y \
  &&  apt install -y \
  vim \
  sudo \
  git \
  make \
  m4 \
  autoconf \
  automake \
  libtool \
  flex \
  python3 \
  zlib1g-dev \
  &&  apt clean

ARG UNAME
ARG UID
ARG GID

RUN if [ "${UNAME}" != "root" ] ; then groupadd -g ${GID} ${UNAME} \
  &&  useradd -ms /bin/bash  -u "${UID}" -g "${GID}" ${UNAME} ; fi

RUN mkdir -p /home/${UNAME} \
  && chown ${UNAME}:${UNAME} /home/${UNAME}

USER ${UNAME}

FROM ${RELEASE_IMAGE} AS release

ARG port=2222

RUN apt update && apt install -y --no-install-recommends \
  openssh-server \
  openssh-client \
  libcap2-bin \
  && rm -rf /var/lib/apt/lists/*
# Add priviledge separation directoy to run sshd as root.
RUN mkdir -p /var/run/sshd
# Add capability to run sshd as non-root.
RUN setcap CAP_NET_BIND_SERVICE=+eip /usr/sbin/sshd
RUN apt remove libcap2-bin -y

# Allow OpenSSH to talk to containers without asking for confirmation
# by disabling StrictHostKeyChecking.
# mpi-operator mounts the .ssh folder from a Secret. For that to work, we need
# to disable UserKnownHostsFile to avoid write permissions.
# Disabling StrictModes avoids directory and files read permission checks.
RUN sed -i "s/[ #]\(.*StrictHostKeyChecking \).*/ \1no/g" /etc/ssh/ssh_config \
  && echo "    UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config \
  && sed -i "s/[ #]\(.*Port \).*/ \1$port/g" /etc/ssh/ssh_config \
  && sed -i "s/#\(StrictModes \).*/\1no/g" /etc/ssh/sshd_config \
  && sed -i "s/#\(Port \).*/\1$port/g" /etc/ssh/sshd_config

RUN useradd -m mpiuser
WORKDIR /home/mpiuser
# Configurations for running sshd as non-root.
RUN echo "PidFile /home/mpiuser/sshd.pid" >> /home/mpiuser/.sshd_config
RUN echo "HostKey /home/mpiuser/.ssh/id_rsa" >> /home/mpiuser/.sshd_config
RUN echo "StrictModes no" >> /home/mpiuser/.sshd_config
RUN echo "Port $port" >> /home/mpiuser/.sshd_config

ARG OMPI_PREFIX_PATH=/opt/openmpi
COPY --chown=root:root build ${OMPI_PREFIX_PATH}
RUN ln -s ${OMPI_PREFIX_PATH}/bin/* /bin/
RUN ln -s ${OMPI_PREFIX_PATH}/lib/* /lib/
