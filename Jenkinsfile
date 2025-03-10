pipeline {
    agent any

    environment {
        REGISTRY = "cr.yandex/crp7mdc71bpnqapssran"  // Замените на ваш registry_id
        APP_NAME = "nginx-static-app"
    }

    stages {
        stage('Get IAM Token') {
            steps {
                withCredentials([string(credentialsId: 'yandex-api-key', variable: 'API_KEY')]) {
                    script {
                        // Безопасный запрос IAM-токена
                        def response = sh(
                            script: """
                                curl -s -d '{"yandexPassportOauthToken": "${env.API_KEY}"}' \
                                -H "Content-Type: application/json" \
                                https://iam.api.cloud.yandex.net/iam/v1/tokens
                            """,
                            returnStdout: true
                        )
                        
                        // Проверка ответа
                        if (response == null || response.isEmpty()) {
                            error("Не удалось получить IAM-токен: пустой ответ от API")
                        }
                        
                        // Парсинг JSON
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
                    // Проверка токена
                    if (env.IAM_TOKEN == null) {
                        error("IAM_TOKEN не определен")
                    }
                    
                    // Аутентификация и пуш
                    sh "echo ${env.IAM_TOKEN} | docker login cr.yandex --username iam --password-stdin"
                    sh "docker push ${REGISTRY}/${APP_NAME}:${env.GIT_COMMIT}"
                }
            }
        }
    }
}