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
                        // Получение IAM-токена
                        def response = sh(
                            script: """
                                curl -sS -d '{"yandexPassportOauthToken": "${env.API_KEY}"}' \
                                -H "Content-Type: application/json" \
                                https://iam.api.cloud.yandex.net/iam/v1/tokens
                            """,
                            returnStdout: true
                        )
                        
                        // Парсинг и проверка токена
                        def json = readJSON text: response
                        env.IAM_TOKEN = json?.iamToken ?: error("IAM-токен не получен")
                    }
                }
            }
        }

        stage('Build & Push') {
            steps {
                script {
                    // Сборка образа
                    docker.build("${REGISTRY}/${APP_NAME}:${env.GIT_COMMIT}", ".")
                    
                    // Аутентификация и пуш
                    sh """
                        echo "${env.IAM_TOKEN}" | \
                        docker login cr.yandex --username iam --password-stdin
                        
                        docker push "${REGISTRY}/${APP_NAME}:${env.GIT_COMMIT}"
                    """
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout cr.yandex'  // Всегда выходим из реестра
        }
        failure {
            emailext body: "Сборка ${env.JOB_NAME} упала!",
                     subject: "FAILED: ${env.JOB_NAME}",
                     to: 'dev@example.com'
        }
    }
}