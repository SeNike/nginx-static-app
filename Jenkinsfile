pipeline {
    agent any

    environment {
        REGISTRY = "cr.yandex/crpoa9bq12dseorjv6jl"
        APP_NAME = "nginx-static-app"
        REPO_URL = "https://github.com/SeNike/nginx-static-app.git"
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm

                script {
                    env.TAGNAME = sh(
                        script: 'git describe --tags --exact-match HEAD || echo ""',
                        returnStdout: true
                    ).trim()
                    
                    echo env.TAGNAME ? "✅ Используется тег: ${env.TAGNAME}" : "ℹ️ Сборка без тега, используем latest"
                }
            }
        }
        

        stage('Validate Files') {
            steps {
                script {
                    def requiredFiles = ['Dockerfile', 'nginx.conf', 'index.html', 'nginx-app.yaml']
                    requiredFiles.each { file ->
                        if (!fileExists(file)) {
                            error("🚨 Отсутствует обязательный файл: ${file}")
                        }
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
                                curl -sS -d '{"yandexPassportOauthToken": "${API_KEY}"}' \
                                -H "Content-Type: application/json" \
                                https://iam.api.cloud.yandex.net/iam/v1/tokens
                            """,
                            returnStdout: true
                        )
                        
                        if (response?.trim() == "") {
                            error("🚨 Пустой ответ от API IAM")
                        }

                        try {
                            def json = readJSON text: response
                            env.IAM_TOKEN = json.iamToken
                        } catch (Exception e) {
                            error("🚨 Ошибка парсинга токена: ${e.message}")
                        }
                    }
                }
            }
        }

        stage('Build & Push') {
            steps {
                script {
                    def imageTag = env.TAGNAME ? "${env.REGISTRY}/${env.APP_NAME}:${env.TAGNAME}" : "${env.REGISTRY}/${env.APP_NAME}:latest"

                    docker.build(imageTag, ".")
                    
                    sh """
                        set +x
                        echo '${env.IAM_TOKEN}' | \
                        docker login cr.yandex --username iam --password-stdin
                        docker push "${imageTag}"
                        set +x
                    """
                }
            }
        }

        stage('Kubernetes Deploy') {
            when {
                expression { env.TAGNAME != null && env.TAGNAME != "" }
            }
            steps {
                script {
                    sh """
                    sed -i "s|image:.*|image: ${REGISTRY}/${APP_NAME}:${env.TAGNAME}|g" nginx-app.yaml
                    export PATH="/var/lib/jenkins/yandex-cloud/bin:$PATH"
                    kubectl apply -f nginx-app.yaml --kubeconfig /home/se/.kube/config
                    """
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout cr.yandex || true'
        }
    }
}
