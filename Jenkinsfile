pipeline {
    agent any

    environment {
        REGISTRY = "cr.yandex/crp7mdc71bpnqapssran"
        APP_NAME = "nginx-static-app"
    }

    stages {
        stage('Check for Tag') {
            steps {
                script {
                    // Получаем текущий тег, если он есть
                    env.GIT_TAG_NAME = sh(
                        script: "git describe --tags --exact-match || echo ''",
                        returnStdout: true
                    ).trim()

                    if (!env.GIT_TAG_NAME) {
                        error "Сборка не по тегу. Прерывание пайплайна."
                    }
                }
            }
        }

        stage('Get IAM Token') {
            steps {
                withCredentials([string(credentialsId: 'yc_cred', variable: 'API_KEY')]) {
                    script {
                        def response = sh(
                            script: """
                                curl -sS -d '{"yandexPassportOauthToken": "${env.API_KEY}"}' \
                                -H "Content-Type: application/json" \
                                https://iam.api.cloud.yandex.net/iam/v1/tokens
                            """,
                            returnStdout: true
                        )
                        
                        if (response?.trim() == "") {
                            error("Пустой ответ от API")
                        }
                        
                        try {
                            def json = readJSON text: response
                            env.IAM_TOKEN = json.iamToken
                        } catch (Exception e) {
                            error("Ошибка парсинга JSON: ${e.message}\nОтвет сервера: ${response}")
                        }
                    }
                }
            }
        }

        stage('Build & Push') {
            steps {
                script {
                    def imageTag = "${REGISTRY}/${APP_NAME}:${env.GIT_TAG_NAME}"
                    
                    docker.build(imageTag, ".")
                    
                    sh """
                        echo '${env.IAM_TOKEN}' | \
                        docker login cr.yandex --username iam --password-stdin
                        
                        docker push "${imageTag}"
                    """
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout cr.yandex'
        }
        failure {
            emailext body: "Сборка ${env.JOB_NAME} упала!\nЛоги: ${env.BUILD_URL}console",
                     subject: "FAILED: ${env.JOB_NAME}",
                     to: 'nsvtemp@gmail.com.com'
        }
    }
}
