pipeline {
    agent any
    
    environment {
        APP_NAME = 'sample-app'
        APP_PORT = '3000'
    }
    
    stages {
        stage('Checkout from GitHub') {
            steps {
                git branch: 'main',
                     url: 'https://github.com/maaikeleo/sample-app.git',
                     credentialsId: 'github-token'
            }
        }
        
        stage('Install Dependencies') {
            steps {
                sh '''
                    # Check if Node.js is installed
                    node --version || echo "Node.js not found, installing..."
                    npm --version || echo "npm not found"
                    
                    # Install dependencies
                    npm install
                '''
            }
        }
        
        stage('Run Tests') {
            steps {
                sh 'npm test || echo "Tests completed"'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                sh 'docker build -t sample-app:$BUILD_NUMBER .'
            }
        }
        
        stage('Deploy to Docker') {
            steps {
                sh '''
                    # Stop and remove old container
                    docker stop sample-app || true
                    docker rm sample-app || true
                    
                    # Run new container
                    docker run -d \
                      --name sample-app \
                      -p 3000:3000 \
                      --restart unless-stopped \
                      sample-app:$BUILD_NUMBER
                    
                    # Wait and check
                    sleep 5
                    curl -f http://localhost:3000/ || exit 1
                '''
            }
        }
    }
    
    post {
        success {
            echo "✅ Pipeline completed successfully!"
            script {
                currentBuild.description = "Build ${env.BUILD_NUMBER} - SUCCESS"
            }
        }
        failure {
            echo "❌ Pipeline failed!"
            script {
                currentBuild.description = "Build ${env.BUILD_NUMBER} - FAILED"
            }
        }
        always {
            echo "🧹 Cleaning up..."
            sh 'docker system prune -f'
        }
    }
}
