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

# Install matching version of Chrome webdriver
webdriver_download_dir="$( mktemp --directory )"
webdriver_version="79.0.3945.36"
webdriver_archive="chromedriver_linux64.zip"
webdriver_url="https://chromedriver.storage.googleapis.com"
webdriver_url="${webdriver_url}/${webdriver_version}/${webdriver_archive}"
pushd "${webdriver_download_dir}"
curl --location --remote-name "${webdriver_url}"
unzip "${webdriver_archive}"
chmod 0755 chromedriver
popd

buildah_from_options=""
if [ -n "$1" ]; then
  buildah_from_options="${buildah_from_options} --creds $1"
fi

ctr="$( buildah from --pull --quiet ${buildah_from_options} quay.io/sdase/centos:8-dev )"
mnt="$( buildah mount "${ctr}" )"

mv "${webdriver_download_dir}/chromedriver" "${mnt}/usr/local/bin/"
mkdir --mode 0777 --parent "${mnt}/code"

echo 'nobody:x:99:99:Nobody:/:/sbin/nologin' >> "${mnt}/etc/passwd"
echo 'nobody:x:99:' >> "${mnt}/etc/group"
echo 'nobody:*:0:0:99999:7:::' >> "${mnt}/etc/shadow"

# Options that are used with every `yum` command
dnf_opts=(
  "--disableplugin=*"
  "--installroot=${mnt}"
  "--assumeyes"
  "--setopt=install_weak_deps=false"
  "--releasever=8"
  "--setopt=tsflags=nocontexts,nodocs"
)

# Install CentOS
dnf ${dnf_opts[@]} install dnf

buildah run ${ctr} -- dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
buildah run ${ctr} -- dnf install -y \
  jq \
  gcc \
  make \
  libfaketime \
  vim \
  patch \
  unzip

# Install latest version of Chromium
buildah copy ${ctr} chrome.repo /etc/yum.repos.d/chrome.repo
buildah run ${ctr} -- dnf install -y google-chrome-stable

buildah run ${ctr} dnf clean all
rm -rf "${mnt}/var/cache/yum"

# Get a bill of materials
bill_of_materials="$(
  buildah images --format '{{.Digest}}' quay.io/sdase/centos:8-dev
  rpm \
    --query \
    --all \
    --queryformat "%{NAME} %{VERSION} %{RELEASE} %{ARCH}" \
    --dbpath="${mnt}"/var/lib/rpm \
    | sort
)"

# Get bill of materials hash – the content
# of this script is included in hash, too.
bill_of_materials_hash="$( ( cat "${0}";
  echo "${bill_of_materials}" \
) | sha256sum | awk '{ print $1; }' )"

oci_prefix="org.opencontainers.image"

descr="CentOS development tools including container development tools"

buildah config \
  --label "${oci_prefix}.authors=SDA SE Engineers <engineers@sda-se.io>" \
  --label "${oci_prefix}.url=https://quay.io/sdase/centos-development" \
  --label "${oci_prefix}.source=https://github.com/SDA-SE/centos-development" \
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
