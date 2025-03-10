pipeline {
    agent any

    environment {
        REGISTRY = "cr.yandex/<registry-id>"
        APP_NAME = "nginx-static-app"
    }

    stages {
        stage('Build Docker Image') {
            steps {
                script {
                    dockerImage = docker.build("${REGISTRY}/${APP_NAME}:${env.GIT_COMMIT}", ".")
                }
            }
        }

        stage('Push to YCR') {
            steps {
                script {
                    docker.withRegistry('https://cr.yandex', 'sa-key.json') {
                        dockerImage.push()
                    }
                }
            }
        }

        stage('Tagged Release') {
            when {
                buildingTag()
            }
            steps {
                script {
                    dockerImage.push("${env.TAG_NAME}")
                    sh "kubectl set image deployment/nginx-deployment nginx=${REGISTRY}/${APP_NAME}:${env.TAG_NAME}"
                }
            }
        }
    }
}