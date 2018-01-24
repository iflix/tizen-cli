# Samsung Tizen Web Tools CLI, plus a few shortcuts that make app
# packaging, installation, and launching nice one-liners.

FROM openjdk:8-jre-slim
MAINTAINER Jan Suchy <jan.sandokan@gmail.com>

ENV TIZEN_CLI_INSTALLER_URL http://download.tizen.org/sdk/Installer/tizen-studio_2.1/web-cli_Tizen_Studio_2.1_ubuntu-64.bin

ENV TIZEN_USER user
ENV TIZEN_USER_HOME /home/$TIZEN_USER
ENV TIZEN_STUDIO $TIZEN_USER_HOME/tizen-studio

RUN echo 'deb http://deb.debian.org/debian jessie main' >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get -y install curl libssl1.0.0 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -md $TIZEN_USER_HOME $TIZEN_USER
USER $TIZEN_USER
WORKDIR $TIZEN_USER_HOME

RUN INSTALLER=/tmp/$(basename "$TIZEN_CLI_INSTALLER_URL") \
    && curl "$TIZEN_CLI_INSTALLER_URL" > "$INSTALLER" \
    && chmod 755 "$INSTALLER" \
    && "$INSTALLER" --no-java-check --accept-license $TIZEN_STUDIO \
    && rm "$INSTALLER" \
    && cd $TIZEN_STUDIO/tools/certificate-generator/patches/partner \
    && ./patch.sh $TIZEN_STUDIO \
    && rm -rf \
       $TIZEN_USER_HOME/.package-manager \
       $TIZEN_USER_HOME/tizen-studio/license \
       $TIZEN_USER_HOME/tizen-studio/package-manager

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
