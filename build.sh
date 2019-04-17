#!/bin/bash
# CentOS development container image

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

set -xe

ctr="$( buildah from quay.io/sdase/centos:7 )"
mnt="$( buildah mount "${ctr}" )"

echo 'nobody:x:99:99:Nobody:/:/sbin/nologin' >> "${mnt}/etc/passwd"
echo 'nobody:x:99:' >> "${mnt}/etc/group"
echo 'nobody:*:0:0:99999:7:::' >> "${mnt}/etc/shadow"

yum_opts=(
  "--installroot=${mnt}"
  "--assumeyes"
  "--setopt=install_weak_deps=false"
  "--releasever=/"
  "--setopt=tsflags=nodocs"
)

yum ${yum_opts[@]} groupinstall "Development Tools"
yum ${yum_opts[@]} install epel-release

yum ${yum_opts[@]} install \
  buildah \
  chromium \
  docker \
  jq \
  libfaketime \
  neovim \
  podman \
  skopeo \
  unzip \
  tree \
  yum \
  zsh \
  && true

yum ${yum_opts[@]} clean all
rm -rf "${mnt}/var/cache/yum"

perl -p -i -e 's/^driver = "overlay"$/driver = "vfs"/g' \
  "${mnt}/etc/containers/storage.conf"

cp libpod.conf "${mnt}/etc/containers/"

oci_prefix="org.opencontainers.image"
version="$( buildah run "${ctr}" -- perl -0777 -ne \
  'print "$&\n" if /\d+(\.\d+)*/' /etc/centos-release)"

descr="CentOS development tools including container development tools"

buildah config \
  --label "${oci_prefix}.authors=SDA SE Engineers <cloud@sda-se.com>" \
  --label "${oci_prefix}.url=https://quay.io/sdase/centos-development" \
  --label "${oci_prefix}.source=https://github.com/SDA-SE/centos-development" \
  --label "${oci_prefix}.version=${version}" \
  --label "${oci_prefix}.revision=$( git rev-parse HEAD )" \
  --label "${oci_prefix}.vendor=SDA SE Open Industry Solutions" \
  --label "${oci_prefix}.licenses=AGPL-3.0" \
  --label "${oci_prefix}.title=CentOS development" \
  --label "${oci_prefix}.description=${descr}" \
  --entrypoint '["/bin/zsh"]' \
  "${ctr}"

image="centos-development"
buildah commit --rm "${ctr}" "${image}"

if [ -n "${BUILD_EXPORT_OCI_ARCHIVES}" ]
then
  skopeo copy \
    "containers-storage:localhost/${image}" \
    "oci-archive:${WORKSPACE:-.}/${image//:/-}.tar"

  buildah rmi "${image}"
fi
