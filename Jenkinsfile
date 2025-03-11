pipeline {
    agent any

    parameters {
        gitParameter(
            name: 'VERSION',
            type: 'PT_TAG',
            description: 'Выберите тег для сборки',
            defaultValue: 'origin/main', // Фикс для требования значения по умолчанию
            tagFilter: 'v.*',
            selectedValue: 'DEFAULT',
            sortMode: 'DESCENDING'
        )
    }

    environment {
        REGISTRY = "cr.yandex/crp7mdc71bpnqapssran"
        APP_NAME = "nginx-static-app"
    }

    stages {
        stage('Pre-check') {
            steps {
                script {
                    // Проверяем что выбранный тег существует
                    if (params.VERSION == 'origin/main' || !params.VERSION) {
                        error("Пожалуйста, выберите существующий тег из списка!")
                    }
                    
                    // Убираем префикс origin/ если есть
                    env.TAG_NAME = params.VERSION.replaceFirst('origin/', '')
                }
            }
        }

        stage('Checkout Code') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "refs/tags/${env.TAG_NAME}"]],
                    extensions: [
                        [$class: 'CloneOption', depth: 1, noTags: false, shallow: true]
                    ],
                    userRemoteConfigs: [[
                        url: 'URL_ВАШЕГО_РЕПОЗИТОРИЯ',
                        credentialsId: 'ВАШ_CREDENTIALS_ID'
                    ]]
                ])
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
                    // Собираем образ с версией из тега
                    docker.build("${REGISTRY}/${APP_NAME}:${params.VERSION}", ".")
                    
                    // Дополнительно помечаем как latest
                    docker.build("${REGISTRY}/${APP_NAME}:latest", ".")
                    
                    sh """
                        echo '${env.IAM_TOKEN}' | \
                        docker login cr.yandex --username iam --password-stdin
                        
                        # Пушим обе версии
                        docker push "${REGISTRY}/${APP_NAME}:${params.VERSION}"
                        docker push "${REGISTRY}/${APP_NAME}:latest"
                    """
                }
            }
        }

        stage('Kube') {
            steps {
                script {
                    // Обновляем манифест с актуальной версией
                    sh """
                        sed -i "s|image:.*|image: ${REGISTRY}/${APP_NAME}:${params.VERSION}|g" nginx-app.yaml
                        
                        export KUBECONFIG=/var/lib/jenkins/.kube/config
                        export PATH="/var/lib/jenkins/yandex-cloud/bin:$PATH"
                        kubectl apply -f nginx-app.yaml
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
            emailext body: "Сборка ${env.JOB_NAME} упала!\nВерсия: ${params.VERSION}\nЛоги: ${env.BUILD_URL}console",
                     subject: "FAILED: ${env.JOB_NAME} [${params.VERSION}]",
                     to: 'nsvtemp@gmail.com'
        }
        success {
            emailext body: "Сборка ${env.JOB_NAME} успешно завершена!\nВерсия: ${params.VERSION}\nЛоги: ${env.BUILD_URL}console",
                     subject: "SUCCESS: ${env.JOB_NAME} [${params.VERSION}]",
                     to: 'nsvtemp@gmail.com'
        }
    }
}