pipeline {
    agent any

    parameters {
        gitParameter(
            name: 'VERSION',
            type: 'PT_TAG',
            description: 'Выберите тег для сборки',
            tagFilter: 'v*',
            defaultValue: 'v2.2.14',
            selectedValue: 'DEFAULT',
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
                    env.TAGNAME = params.VERSION.replaceAll('origin/(tags/)?', '')
                    echo "Выбранный тег: ${env.TAGNAME}"
                }
            }
        }

        stage('Checkout Code') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "refs/tags/${env.TAGNAME}"]],
                    extensions: [
                        [$class: 'CloneOption', depth: 1, noTags: false, shallow: true],
                        [$class: 'PruneStaleBranch'],
                        [$class: 'CleanBeforeCheckout']
                    ],
                    userRemoteConfigs: [[
                        url: env.REPO_URL,
                        credentialsId: 'github-creds',
                        refspec: "+refs/tags/${env.TAGNAME}:refs/tags/${env.TAGNAME}"
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
                    def imageLatest = "${env.REGISTRY}/${env.APP_NAME}:latest"
                    def imageTag = "${env.REGISTRY}/${env.APP_NAME}:${env.TAGNAME}"
                    
                    docker.build(imageLatest, ".")
                    docker.build(imageTag, ".")
                    
                    sh """
                        echo '${env.IAM_TOKEN}' | \
                        docker login cr.yandex --username iam --password-stdin
                        
                        docker push "${imageTag}"
                        docker push "${imageLatest}"
                    """
                }
            }
        }

        stage('Kube') {
            steps {
                script {
                    sh """
                        
                        
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
            emailext body: "Сборка ${env.JOB_NAME} упала!\nВерсия: ${env.TAGNAME}\nЛоги: ${env.BUILD_URL}console",
                     subject: "FAILED: ${env.JOB_NAME} [${env.TAGNAME}]",
                     to: 'nsvtemp@gmail.com'
        }
        success {
            emailext body: "Сборка ${env.JOB_NAME} успешно завершена!\nВерсия: ${env.TAGNAME}\nЛоги: ${env.BUILD_URL}console",
                     subject: "SUCCESS: ${env.JOB_NAME} [${env.TAGNAME}]",
                     to: 'nsvtemp@gmail.com'
        }
    }
}
