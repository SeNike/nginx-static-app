pipeline {
    agent any

    environment {
        REGISTRY = "cr.yandex/crp7mdc71bpnqapssran"  // Ваш registry_id
        APP_NAME = "nginx-static-app"
    }

    stages {
        stage('Get IAM Token') {
            steps {
                withCredentials([string(credentialsId: 'yandex-api-key', variable: 'API_KEY')]) {
                    script {
                        // Безопасное получение IAM-токена
                        def response = sh(
                            script: """
                                curl -s -d '{"yandexPassportOauthToken": "${env.API_KEY}"}' \
                                -H "Content-Type: application/json" \
                                https://iam.api.cloud.yandex.net/iam/v1/tokens
                            """,
                            returnStdout: true
                        )
                        
                        // Используем readJSON из Pipeline Utility Steps
                        def json = readJSON text: response
                        env.IAM_TOKEN = json.iamToken
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${REGISTRY}/${APP_NAME}:${env.GIT_COMMIT}", ".")
                }
            }
        }

        stage('Push to YCR') {
            steps {
                script {
                    sh(script: "echo ${env.IAM_TOKEN} | docker login cr.yandex --username iam --password-stdin", label: "Login to YCR")
                    sh "docker push ${REGISTRY}/${APP_NAME}:${env.GIT_COMMIT}"
                }
            }
        }
    }
}