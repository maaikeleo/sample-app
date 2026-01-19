pipeline {
    agent any
    triggers {
        pollSCM('*/5 * * * *')
    }
    environment {
        APP_NAME = 'sample-app'
        APP_PORT = '3000'
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_TOKEN = credentials('sonarqube-token')
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                     url: 'https://github.com/maaikeleo/sample-app.git',
                     credentialsId: 'github-token'
            }
        }
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        # Run SonarQube analysis
                        sonar-scanner \
                          -Dsonar.projectKey=${APP_NAME} \
                          -Dsonar.projectName="${APP_NAME}" \
                          -Dsonar.projectVersion=${BUILD_NUMBER} \
                          -Dsonar.sources=. \
                          -Dsonar.host.url=${SONAR_HOST_URL} \
                          -Dsonar.login=${SONAR_TOKEN}
                    '''
                }
            }
        }
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false
                }
            }
        }
        stage('Build & Deploy') {
            steps {
                sh '''
                    npm install
                    docker build -t ${APP_NAME}:${BUILD_NUMBER} .
                    docker stop ${APP_NAME} 2>/dev/null || true
                    docker rm ${APP_NAME} 2>/dev/null || true
                    docker run -d --name ${APP_NAME} -p ${APP_PORT}:${APP_PORT} ${APP_NAME}:${BUILD_NUMBER}
                    sleep 3
                    curl -f http://localhost:${APP_PORT}/ || exit 1
                '''
            }
        }
    }
}
