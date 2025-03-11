pipeline {
    agent any

    environment {
        REGISTRY = "cr.yandex/crp7mdc71bpnqapssran"
        APP_NAME = "nginx-static-app"
    }

    stages {
        stage('Get IAM Token') {
            steps {
                withCredentials([string(credentialsId: 'yc_cred', variable: 'API_KEY')]) {
                    script {
                        // Безопасный запрос с корректным JSON
                        def response = sh(
                            script: """
                                curl -sS -d '{"yandexPassportOauthToken": "${env.API_KEY}"}' \
                                -H "Content-Type: application/json" \
                                https://iam.api.cloud.yandex.net/iam/v1/tokens
                            """,
                            returnStdout: true
                        )
                        
                        // Проверка ответа
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
                    docker.build("${REGISTRY}/${APP_NAME}:${env.GIT_COMMIT}", ".")
                    
                    sh """
                        echo '${env.IAM_TOKEN}' | \
                        docker login cr.yandex --username iam --password-stdin
                        
                        docker push "${REGISTRY}/${APP_NAME}:${env.GIT_COMMIT}"
                    """
                }
            }
        }
        stage('Kube') {
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
                        ).trim()

                        def json = readJSON text: response
                        env.IAM_TOKEN = json.iamToken
                        
                        sh """
                            export KUBECONFIG=\$(mktemp)
                            export PATH="/home/se/yandex-cloud/bin:$PATH"
                            yc managed-kubernetes cluster get-credentials your-cluster-id --external --token=${env.IAM_TOKEN}
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
            emailext body: "Сборка ${env.JOB_NAME} упала!\nЛоги: ${env.BUILD_URL}console",
                     subject: "FAILED: ${env.JOB_NAME}",
                     to: 'nsvtemp@gmail.com'
        }
    }
}