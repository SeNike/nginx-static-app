pipeline {
    agent any

    environment {
        REGISTRY = "cr.yandex/crp7mdc71bpnqapssran"
        APP_NAME = "nginx-static-app"
        API_KEY = credentials('yandex-api-key') // ID вашего API-ключа
    }

    stages {
        stage('Get IAM Token') {
            steps {
                script {
                    // Получаем IAM-токен через API Yandex Cloud
                    def response = sh(script: """
                        curl -s -d '{"yandexPassportOauthToken": "${API_KEY}"}' \
                        -H "Content-Type: application/json" \
                        https://iam.api.cloud.yandex.net/iam/v1/tokens
                    """, returnStdout: true)
                    
                    def json = readJSON text: response
                    env.IAM_TOKEN = json.iamToken
                }
            }
        }

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
                    // Используем IAM-токен для аутентификации
                    sh "echo ${env.IAM_TOKEN} | docker login cr.yandex --username iam --password-stdin"
                    dockerImage.push()
                }
            }
        }
    }
}