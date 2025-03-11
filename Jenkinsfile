pipeline {
    agent any

    parameters {
        gitParameter(
            name: 'VERSION',
            type: 'PT_TAG',
            description: 'Выберите тег для сборки',
            tagFilter: 'v*',
            defaultValue: 'v2.2.5',
            selectedValue: 'v2.2.5',
            sortMode: 'DESCENDING'
        )
    }

    environment {
        REGISTRY = "cr.yandex/crp7mdc71bpnqapssran"
        APP_NAME = "nginx-static-app"
        REPO_URL = "https://github.com/SeNike/nginx-static-app.git"
    }

    stages {
        stage('Pre-check') {
            steps {
                script {
                    if (params.VERSION == 'origin/main') {
                        error("Пожалуйста, выберите тег из списка!")
                    }
                    env.TAG_NAME = params.VERSION.replaceAll('origin/(tags/)?', '')
                }
            }
        }

        stage('Checkout Code') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "refs/tags/${env.TAG_NAME}"]],
                    extensions: [
                        [$class: 'CloneOption', depth: 1, noTags: false, shallow: true],
                        [$class: 'PruneStaleBranch'],
                        [$class: 'CleanBeforeCheckout']
                    ],
                    userRemoteConfigs: [[
                        url: env.REPO_URL,
                        credentialsId: 'github-creds', // Замените на ваш реальный ID
                        refspec: '+refs/tags/*:refs/remotes/origin/tags/*'
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
                    docker.build("${REGISTRY}/${APP_NAME}:latest", ".")
                    docker.build("${REGISTRY}/${APP_NAME}:${env.TAG_NAME}", ".")
                    
                    sh """
                        echo '${env.IAM_TOKEN}' | \
                        docker login cr.yandex --username iam --password-stdin
                        
                        docker push "${REGISTRY}/${APP_NAME}:${env.TAG_NAME}"
                        docker push "${REGISTRY}/${APP_NAME}:latest"
                    """
                }
            }
        }

        stage('Kube') {
            steps {
                script {
                    sh """
                        sed -i "s|image:.*|image: ${REGISTRY}/${APP_NAME}:${env.TAG_NAME}|g" nginx-app.yaml
                        
                        export KUBECONFIG=/var/lib/jenkins/.kube/config
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
            emailext body: "Сборка ${env.JOB_NAME} упала!\nВерсия: ${env.TAG_NAME}\nЛоги: ${env.BUILD_URL}console",
                     subject: "FAILED: ${env.JOB_NAME} [${env.TAG_NAME}]",
                     to: 'nsvtemp@gmail.com'
        }
        success {
            emailext body: "Сборка ${env.JOB_NAME} успешно завершена!\nВерсия: ${env.TAG_NAME}\nЛоги: ${env.BUILD_URL}console",
                     subject: "SUCCESS: ${env.JOB_NAME} [${env.TAG_NAME}]",
                     to: 'nsvtemp@gmail.com'
        }
    }
}