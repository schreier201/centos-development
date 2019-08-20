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
  test -n "${webdriver_download_dir}" && rm -rf "${webdriver_download_dir}"
}

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
build_dir="${dir}/build"


webdriver_download_dir="$( mktemp --directory )"
webdriver_version="77.0.3865.10"
webdriver_archive="chromedriver_linux64.zip"
webdriver_url="https://chromedriver.storage.googleapis.com"
webdriver_url="${webdriver_url}/${webdriver_version}/${webdriver_archive}"
pushd "${webdriver_download_dir}"
curl --location --remote-name "${webdriver_url}"
unzip "${webdriver_archive}"
popd

ctr="$( buildah from --pull --quiet quay.io/sdase/centos:7 )"
mnt="$( buildah mount "${ctr}" )"

mv "${webdriver_download_dir}/chromedriver" "${mnt}/usr/local/bin/"

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
rpm --root "${mnt}" --import "${mnt}/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7"

yum ${yum_opts[@]} install \
  buildah \
  chromium \
  jq \
  libfaketime \
  neovim \
  patch \
  podman \
  skopeo \
  unzip \
  tree \
  yum \
  zsh \
  && true

yum ${yum_opts[@]} install centos-release-scl
rpm --root "${mnt}" --import "${mnt}/etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-SCLo"
yum ${yum_opts[@]} install rh-git218-git-core

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
buildah commit --quiet --rm "${ctr}" "${image}" && ctr=

if [ -n "${BUILD_EXPORT_OCI_ARCHIVES}" ]
then
  mkdir --parent "${build_dir}"
  buildah push --quiet "${image}" \
    "oci-archive:${build_dir}/${image//:/-}.tar"

  buildah rmi "${image}"
fi
