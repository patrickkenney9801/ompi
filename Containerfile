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
  && apt clean
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

ARG UID=9801
ARG GID=9801
ARG UNAME=mpiuser
RUN if [ "${UNAME}" != "root" ] && ! [ id ${UID} ] ; then groupadd -g ${GID} ${UNAME} \
  && useradd -ms /bin/bash  -u "${UID}" -g "${GID}" ${UNAME} \
  && mkdir -p /home/${UNAME} \
  && chown ${UNAME}:${UNAME} /home/${UNAME}; \
  fi

WORKDIR /home/${UNAME}
# Configurations for running sshd as non-root.
RUN echo "PidFile /home/${UNAME}/sshd.pid" >> /home/${UNAME}/.sshd_config
RUN echo "HostKey /home/${UNAME}/.ssh/id_rsa" >> /home/${UNAME}/.sshd_config
RUN echo "StrictModes no" >> /home/${UNAME}/.sshd_config
RUN echo "Port $port" >> /home/${UNAME}/.sshd_config

RUN apt update && apt install -y --no-install-recommends \
  zlib1g \
  && apt clean

ARG OMPI_PREFIX_PATH=/opt/openmpi
COPY --chown=root:root build ${OMPI_PREFIX_PATH}
RUN ln -s ${OMPI_PREFIX_PATH}/bin/* /bin/
RUN ln -s ${OMPI_PREFIX_PATH}/lib/* /lib/
RUN ln -s ${OMPI_PREFIX_PATH} /opt/openmpi
RUN ln -s ${OMPI_PREFIX_PATH} /usr/lib/x86_64-linux-gnu/openmpi

USER ${UNAME}
