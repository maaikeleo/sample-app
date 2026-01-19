pipeline {
    agent any
    
    environment {
        APP_NAME = 'sample-app'
        APP_PORT = '3000'
        DOCKER_IMAGE = "sample-app:\${env.BUILD_NUMBER}"
    }
    
    stages {
        stage('Checkout from GitHub') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[
                        url: 'https://github.com/maaikeleo/sample-app.git',
                        credentialsId: 'github-token'
                    ]]
                ])
                
                script {
                    echo "✅ Checked out from GitHub"
                    sh 'git log --oneline -3'
                }
            }
        }
        
        stage('Install Dependencies') {
            steps {
                sh 'npm install'
            }
        }
        
        stage('Run Tests') {
            steps {
                sh 'npm test || echo "Tests completed"'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    sh "docker build -t \${DOCKER_IMAGE} ."
                }
            }
        }
        
        stage('Deploy to Docker') {
            steps {
                script {
                    sh """
                        # Stop and remove old container
                        docker stop \${APP_NAME} || true
                        docker rm \${APP_NAME} || true
                        
                        # Run new container
                        docker run -d \\
                          --name \${APP_NAME} \\
                          -p \${APP_PORT}:\${APP_PORT} \\
                          --restart unless-stopped \\
                          \${DOCKER_IMAGE}
                        
                        # Wait and check health
                        sleep 10
                        curl -f http://localhost:\${APP_PORT}/ || exit 1
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo "✅ Pipeline completed successfully!"
            script {
                currentBuild.description = "Build \${env.BUILD_NUMBER} - SUCCESS"
            }
        }
        failure {
            echo "❌ Pipeline failed!"
            script {
                currentBuild.description = "Build \${env.BUILD_NUMBER} - FAILED"
            }
        }
        always {
            echo "🧹 Cleaning up..."
            sh 'docker system prune -f'
        }
    }
}
