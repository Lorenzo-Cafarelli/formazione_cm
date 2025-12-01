pipeline {
    agent any
    environment {
        REGISTRY = "localhost:5050"
        IMAGE_NAME = "custom_app"
        DEPLOY_PORT = "3000"
    }
    stages {
        stage('Build & Push') {
            steps {
                script {
                    sh "echo 'FROM alpine:latest' > Dockerfile"
                    sh "echo 'CMD [\"sleep\", \"3600\"]' >> Dockerfile"
                    sh "sudo docker build -t ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER} ."
                    sh "sudo docker push ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}"
                }
            }
        }
        stage('Deploy') {
            steps {
                script {
                    sh "sudo docker pull ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}"
                    sh "sudo docker rm -f ${IMAGE_NAME}_run || true"
                    sh """
                        sudo docker run -d \
                        --name ${IMAGE_NAME}_run \
                        --restart always \
                        -p ${DEPLOY_PORT}:80 \
                        ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}
                    """
                }
            }
        }
    }
}
