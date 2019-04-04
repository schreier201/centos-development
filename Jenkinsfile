// CentOS image

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.

// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pipeline {
  agent {
    label 'docker'
  }
  triggers {
    upstream(
      upstreamProjects: 'SDA Open Industry Solutions/centos/master',
      threshold: hudson.model.Result.SUCCESS
    )
  }
  options {
    ansiColor 'xterm'
    skipStagesAfterUnstable()
    timeout time: 1, unit: 'HOURS'
    lock resource: 'quay.io/sdase/centos'
  }
  environment {
    // Attention: When changing this, change it in the Dockerfile, too.
    CENTOS_VERSION = '7.6.1810'
  }
  stages {
    stage("Build image") {
      steps {
        sh """
          docker build \
            --tag quay.io/sdase/centos-development:build \
            --pull \
            --no-cache \
            --rm \
            .
        """
      }
    }
    stage("Compare bill of materials") {
      steps {
        script {
          def currentBillOfMaterials = sh returnStdout: true,
              returnStatus: true, script: """
            docker run --rm --tty quay.io/sdase/centos-development:${CENTOS_VERSION} \
            rpm -qa --qf "%{NAME} %{ARCH} %{VERSION} %{RELEASE} %{SHA1HEADER}\n"
          """
          def newBillOfMaterials = sh returnStdout: true, script: """
            docker run --rm --tty quay.io/sdase/centos-development:build \
            rpm -qa --qf "%{NAME} %{ARCH} %{VERSION} %{RELEASE} %{SHA1HEADER}\n"
          """
          env.BILL_OF_MATERIALS_CHANGED = \
            "${currentBillOfMaterials != newBillOfMaterials}"
        }
      }
    }
    stage("Publish image") {
      when {
        beforeAgent true
        allOf {
          branch 'master'
          environment name: 'BILL_OF_MATERIALS_CHANGED', value: 'true'
        }
      }
      steps {
        withCredentials([usernamePassword(
            credentialsId: 'quay-io-sdase-docker-auth',
            usernameVariable: 'imageRegistryUser',
            passwordVariable: 'imageRegistryPassword')]) {
          sh """
            docker login \
              --username "${imageRegistryUser}" \
              --password "${imageRegistryPassword}" \
              quay.io
          """
        }
        script {

          def tokens = env.CENTOS_VERSION.tokenize('.')
          def tags = (1..tokens.size()).collect {
            tokens.subList(0, it).join('.')
          } + "${env.CENTOS_VERSION}-${env.BUILD_NUMBER}"

          tags.each { tag ->
            sh """
              docker tag quay.io/sdase/centos-development:build quay.io/sdase/centos-development:${tag}
              docker push quay.io/sdase/centos-development:${tag}
            """
          }
        }
      }
    }
  }
}
