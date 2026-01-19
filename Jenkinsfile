pipeline {
    agent any
    triggers {
        pollSCM('*/5 * * * *')
    }
    environment {
        APP_NAME = 'sample-app'
        APP_PORT = '3000'
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                     url: 'https://github.com/maaikeleo/sample-app.git',
                     credentialsId: 'github-token'
            }
        }
        stage('Build & Deploy') {
            steps {
                sh '''
                    npm install
                    docker build -t sample-app:$BUILD_NUMBER .
                    docker stop sample-app || true
                    docker rm sample-app || true
                    docker run -d --name sample-app -p 3000:3000 sample-app:$BUILD_NUMBER
                    sleep 3
                    curl -f http://localhost:3000/ || exit 1
                '''
            }
        }
    }
}
