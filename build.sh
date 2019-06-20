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

trap cleanup INT EXIT
cleanup() {
  test -n "${ctr}" && buildah rm "${ctr}" || true
}

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
build_dir="${dir}/build"

ctr="$( buildah from --pull --quiet quay.io/sdase/centos:7 )"
mnt="$( buildah mount "${ctr}" )"

mkdir --mode 0777 --parent "${mnt}/code"

echo 'nobody:x:99:99:Nobody:/:/sbin/nologin' >> "${mnt}/etc/passwd"
echo 'nobody:x:99:' >> "${mnt}/etc/group"
echo 'nobody:*:0:0:99999:7:::' >> "${mnt}/etc/shadow"

yum_opts=(
  "--installroot=${mnt}"
  "--assumeyes"
  "--setopt=install_weak_deps=false"
  "--releasever=7"
  "--setopt=tsflags=nodocs"
)

yum ${yum_opts[@]} groupinstall "Development Tools"
yum ${yum_opts[@]} install epel-release

yum ${yum_opts[@]} install \
  buildah \
  chromium \
  docker \
  java-11-openjdk \
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

# perl -p -i -e 's/^driver = "overlay"$/driver = "vfs"/g' \
#   "${mnt}/etc/containers/storage.conf"

# cp libpod.conf "${mnt}/etc/containers/"

# Get a bill of materials
bill_of_materials="$(
  buildah images --format '{{.Digest}}' quay.io/sdase/centos:7
  rpm \
    --query \
    --all \
    --queryformat "%{NAME} %{VERSION} %{RELEASE} %{ARCH}" \
    --dbpath="${mnt}"/var/lib/rpm \
    | sort
  cat libpod.conf
)"

# Get bill of materials hash – the content
# of this script is included in hash, too.
bill_of_materials_hash="$( ( cat "${0}";
  echo "${bill_of_materials}" \
) | sha256sum | awk '{ print $1; }' )"

oci_prefix="org.opencontainers.image"
version="$( perl -0777 -ne \
  'print "$&\n" if /\d+(\.\d+)*/' "${mnt}"/etc/centos-release )"

descr="CentOS development tools including container development tools"

buildah config \
  --label "${oci_prefix}.authors=SDA SE Engineers <engineers@sda-se.io>" \
  --label "${oci_prefix}.url=https://quay.io/sdase/centos-development" \
  --label "${oci_prefix}.source=https://github.com/SDA-SE/centos-development" \
  --label "${oci_prefix}.version=${version}" \
  --label "${oci_prefix}.revision=$( git rev-parse HEAD )" \
  --label "${oci_prefix}.vendor=SDA SE Open Industry Solutions" \
  --label "${oci_prefix}.licenses=AGPL-3.0" \
  --label "${oci_prefix}.title=CentOS development" \
  --label "${oci_prefix}.description=${descr}" \
  --label "io.sda-se.image.bill-of-materials-hash=$( \
    echo "${bill_of_materials_hash}" )" \
  --workingdir "/code" \
  "${ctr}"

image="centos-development"
buildah commit --quiet --rm "${ctr}" "${image}"

if [ -n "${BUILD_EXPORT_OCI_ARCHIVES}" ]
then
  mkdir --parent "${build_dir}"
  buildah push --quiet "${image}" \
    "oci-archive:${build_dir}/${image//:/-}.tar"

  buildah rmi "${image}"
fi
