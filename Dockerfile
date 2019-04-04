# CentOS image

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Attention: When changing this, change it in the Jenkinsfile, too.
FROM quay.io/sdase/centos:7.6.1810

# https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL \
  # Contact details of the people or organization responsible for the image
  org.opencontainers.image.authors="SDA SE Engineers <cloud@sda-se.com>" \
  # URL to find more information on the image
  org.opencontainers.image.url="https://quay.io/repository/sdase/centos-development" \
  # URL to get source code for building the image
  org.opencontainers.image.source="https://github.com/SDA-SE/centos-development" \
  # Version of the packaged software
  org.opencontainers.image.version="7" \
  # Source control revision identifier for the packaged software.
  org.opencontainers.image.vendor="SDA SE Open Industry Solutions" \
  # License(s) under which contained software is distributed as an SPDX License
  # Expression.
  org.opencontainers.image.licenses="AGPL-3.0" \
  # Human-readable title of the image
  org.opencontainers.image.title="CentOS development tools" \
  # Human-readable description of the software packaged in the image
  org.opencontainers.image.description="" \
  # Base image
  se.sda.oci.images.centos.base="docker.io/centos-development:7.6.1810" \
  # https://docs.docker.com/engine/reference/builder/#label
  maintainer="cloud@sda-se.com"

RUN \
  yum -y groupinstall "Development Tools" && \
  yum -y clean all && \
  rm -rf /var/cache/yum && \
  true
