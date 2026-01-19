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
                    # Clean up first
                    docker stop ${APP_NAME} 2>/dev/null || true
                    docker rm ${APP_NAME} 2>/dev/null || true
                    
                    # Build
                    npm install
                    docker build -t ${APP_NAME}:${BUILD_NUMBER} .
                    
                    # Run with debugging
                    docker run -d \
                      --name ${APP_NAME} \
                      -p ${APP_PORT}:${APP_PORT} \
                      ${APP_NAME}:${BUILD_NUMBER}
                    
                    # Wait longer and check logs
                    sleep 5
                    echo "Container status:"
                    docker ps | grep ${APP_NAME}
                    
                    echo "Container logs:"
                    docker logs ${APP_NAME}
                    
                    # Try to connect
                    curl -v --retry 5 --retry-delay 2 http://localhost:${APP_PORT}/ || echo "Check container logs above"
                '''
            }
        }
    }
}
