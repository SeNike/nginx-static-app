pipeline {
    agent any

    environment {
        REGISTRY = "cr.yandex/crp7mdc71bpnqapssran"
        APP_NAME = "nginx-static-app"
        REPO_URL = "https://github.com/SeNike/nginx-static-app.git"
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: 'refs/tags/*']],
                    extensions: [
                        [$class: 'CloneOption', depth: 0, noTags: false, shallow: false],
                        [$class: 'PruneStaleBranch'],
                        [$class: 'CleanBeforeCheckout']
                    ],
                    userRemoteConfigs: [[
                        url: env.REPO_URL,
                        credentialsId: 'github-creds' // Убедитесь, что credentials существуют
                    ]]
                ])
            }
        }

        stage('Extract Git Tag') {
            steps {
                script {
                    env.TAGNAME = sh(
                        script: 'git describe --tags --exact-match HEAD',
                        returnStdout: true
                    ).trim()
                    
                    if (!env.TAGNAME) {
                        error("Сборка возможна только из тега Git!")
                    }
                    echo "Используется тег: ${env.TAGNAME}"
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
    }
}