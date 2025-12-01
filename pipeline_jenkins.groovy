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
    }
}
