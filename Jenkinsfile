pipeline {
  agent any
  
  triggers {
    cron("30 */4 * * *")
  }
  
  options {
    buildDiscarder(logRotator(numToKeepStr: '5'))
  }
  
  environment {
    DOCKERHUB_CREDENTIALS = credentials("dprus-dockerhub")
    REBUILD_IMAGE = false
    UPSTREAM_IMAGE_NAME = "dprus/python-alpine-openssl-rsync-jre"
    DOCKERHUB_USERNAME = "dprus"
    DOCKERHUB_REPO_NAME = "python-alpine-openssl-rsync-jre-msmtp"
    DOCKERHUB_REPO_TAG = "latest"
  }
  
  stages {
    
    stage("Initialize Variables") {
      steps {
        script {
          try {
            CURRENT_UPSTREAM_DOCKERHUB_IMAGE_DIGEST = params.CURRENT_UPSTREAM_DOCKERHUB_IMAGE_DIGEST
          } catch (Exception e) {
            echo("Could not read CURRENT_UPSTREAM_DOCKERHUB_IMAGE_DIGEST from parameters. Assuming this is the first run of the pipeline. Exception: ${e}")
            CURRENT_UPSTREAM_DOCKERHUB_IMAGE_DIGEST = ""
          }
        }
      }
    }
    
    stage("Login to Docker Hub") {
      steps {
        sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'
      }
    }
    
    stage("Check for git repository changes") {
      steps {
        script {
          if(currentBuild.changeSets.size() > 0) {
            echo("There are changes in the git repository since the last build. Image will be rebuilt.")
            REBUILD_IMAGE = true
          }
          else {
            echo("There are NO changes in the git repository since the last build. This will not trigger an image rebuild.")
          }
        }
      }
    }
    
    stage("Fetch new Upstream Docker Hub Image Digest") {
      steps {
        script {
          NEW_UPSTREAM_DOCKERHUB_IMAGE_DIGEST = sh(
            script: '''
              docker manifest inspect ${UPSTREAM_IMAGE_NAME} -v | jq '.[].Descriptor | select (.platform.architecture=="amd64" and .platform.os=="linux")' | jq -r '.digest'
            ''',
            returnStdout: true
          ).trim()
          echo("CURRENT_UPSTREAM_DOCKERHUB_IMAGE_DIGEST: '${CURRENT_UPSTREAM_DOCKERHUB_IMAGE_DIGEST}'")
          echo("NEW_UPSTREAM_DOCKERHUB_IMAGE_DIGEST: '${NEW_UPSTREAM_DOCKERHUB_IMAGE_DIGEST}'")
          if (CURRENT_UPSTREAM_DOCKERHUB_IMAGE_DIGEST != NEW_UPSTREAM_DOCKERHUB_IMAGE_DIGEST) {
            echo("Upstream Docker Hub image digests are not equal. Image will be rebuilt.")
            REBUILD_IMAGE = true
          } else {
            echo("Upstream Docker Hub image digests are equal. This will not cause an image rebuild.")
          }
        }
      }
    }
    
    stage("Determine if it has been more than 2 weeks since the latest build") {
      steps {
        script {
          if (REBUILD_IMAGE == "false") {
            SECONDS_SINCE_LAST_IMAGE = sh(
              script: '''
                d1=$(curl -s GET https://hub.docker.com/v2/repositories/${DOCKERHUB_USERNAME}/${DOCKERHUB_REPO_NAME}/tags/${DOCKERHUB_REPO_TAG} | jq -r ".last_updated")
                ddiff=$(( $(date "+%s") - $(date -d "$d1" "+%s") ))
                echo $ddiff
              ''',
              returnStdout: true
            ).trim()
            SECONDS_SINCE_LAST_IMAGE_INT = SECONDS_SINCE_LAST_IMAGE.toInteger()
            echo("SECONDS_SINCE_LAST_IMAGE_INT: '${SECONDS_SINCE_LAST_IMAGE_INT}'")
            if (SECONDS_SINCE_LAST_IMAGE_INT > 1209600) { // 1209600 is 2 weeks in seconds
              echo("It has been more than 2 weeks since the last build. Image will be rebuilt.")
              REBUILD_IMAGE = true
            } else {
              echo("Image is newer than 2 weeks. This will not cause an image rebuild.")
            }
          } else {
            echo("Image is already marked for build. Skipping this stage.")
          }
        }
      }
    }
    
    stage("Determine if we should actually build the image.") {
      steps {
        script {
          echo("REBUILD_IMAGE: '${REBUILD_IMAGE}'")
          if (REBUILD_IMAGE == "false") {
            echo("Image will not be rebuilt. This is still a success. Exiting.")
            currentBuild.result = 'ABORTED'
            error("Aborting the job.")
          }
        }
      }
    }
    
    stage("Build") {
      steps {
        sh 'docker build -t ${DOCKERHUB_USERNAME}/${DOCKERHUB_REPO_NAME}:${DOCKERHUB_REPO_TAG} .'
      }
    }
       
    stage("Push image to Docker Hub") {
      steps {
        sh 'docker push ${DOCKERHUB_USERNAME}/${DOCKERHUB_REPO_NAME}:${DOCKERHUB_REPO_TAG}'
      }
    }
    
    stage("Save Persistent Variables") {
      steps {
        script {
          properties([
            parameters([
              string(defaultValue: "${NEW_UPSTREAM_DOCKERHUB_IMAGE_DIGEST}",
                     description: "Current Upstream DockerHub Image Digest",
                     name: 'CURRENT_UPSTREAM_DOCKERHUB_IMAGE_DIGEST',
                     trim: true)
            ])
          ])
        }
      }
    }
  }
  
  post {
    always {
      sh 'docker logout'
    }
  }
}
