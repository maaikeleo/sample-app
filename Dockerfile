pipeline {
    agent any
    
    environment {
        APP_NAME = 'sample-app'
        APP_PORT = '3000'
        DOCKER_IMAGE = "sample-app:\${env.BUILD_NUMBER}"
        DEPLOYMENT_ID = "\${env.BUILD_NUMBER}-\$(date +%Y%m%d%H%M%S)"
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }
    
    stages {
        stage('Checkout from GitHub') {
            steps {
                git branch: 'main',
                     url: 'https://github.com/maaikeleo/sample-app.git',
                     credentialsId: 'github-token'
                
                script {
                    env.GIT_COMMIT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.GIT_BRANCH = sh(script: 'git branch --show-current', returnStdout: true).trim()
                    echo "📦 Repository: https://github.com/maaikeleo/sample-app"
                    echo "🌿 Branch: \${GIT_BRANCH}"
                    echo "🔑 Commit: \${GIT_COMMIT}"
                }
            }
        }
        
        stage('Setup Environment') {
            steps {
                sh '''
                    echo "=== Environment Setup ==="
                    echo "Node.js: $(node --version)"
                    echo "npm: $(npm --version)"
                    echo "Docker: $(docker --version)"
                    echo "Build Number: $BUILD_NUMBER"
                    echo "Workspace: $WORKSPACE"
                '''
            }
        }
        
        stage('Install Dependencies') {
            steps {
                sh 'npm ci --only=production'
            }
        }
        
        stage('Run Tests') {
            steps {
                sh 'npm test -- --passWithNoTests'
            }
            post {
                always {
                    junit '**/test-results.xml'  # If you have JUnit test reports
                }
            }
        }
        
        stage('Code Quality') {
            parallel {
                stage('Linting') {
                    steps {
                        sh 'npm run lint || echo "Linting not configured"'
                    }
                }
                stage('Security Audit') {
                    steps {
                        sh 'npm audit --audit-level=moderate || true'
                    }
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    echo "🔨 Building Docker image..."
                    sh """
                        docker build \\
                          -t \${APP_NAME}:\${env.BUILD_NUMBER} \\
                          -t \${APP_NAME}:latest \\
                          -t \${APP_NAME}:\${GIT_COMMIT} \\
                          --label version=\${env.BUILD_NUMBER} \\
                          --label commit=\${GIT_COMMIT} \\
                          --label build-date=\$(date -u +'%Y-%m-%dT%H:%M:%SZ') .
                    """
                    
                    // List built images
                    sh 'docker images | grep \${APP_NAME}'
                }
            }
        }
        
        stage('Test Docker Image') {
            steps {
                sh '''
                    # Run container for testing
                    docker run --rm \
                      --name ${APP_NAME}-test \
                      -p 3001:3000 \
                      -d sample-app:${BUILD_NUMBER}
                    
                    # Wait and test
                    sleep 5
                    curl -f http://localhost:3001/health || exit 1
                    
                    # Cleanup
                    docker stop ${APP_NAME}-test
                '''
            }
        }
        
        stage('Deploy to Production') {
            steps {
                script {
                    echo "🚀 Deploying version ${env.BUILD_NUMBER}..."
                    
                    sh """
                        # Create deployment directory
                        mkdir -p $WORKSPACE/deployments
                        
                        # Create docker-compose file
                        cat > $WORKSPACE/deployments/docker-compose.yml << 'EOF'
version: '3.8'
services:
  ${APP_NAME}:
    image: ${APP_NAME}:${env.BUILD_NUMBER}
    container_name: ${APP_NAME}
    restart: unless-stopped
    ports:
      - "${APP_PORT}:${APP_PORT}"
    environment:
      - NODE_ENV=production
      - PORT=${APP_PORT}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${APP_PORT}/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF
                        
                        # Deploy using docker-compose
                        cd $WORKSPACE/deployments
                        
                        # Stop and remove old container
                        docker-compose down || true
                        
                        # Start new container
                        docker-compose up -d
                        
                        # Wait for health check
                        echo "Waiting for application to be healthy..."
                        for i in {1..30}; do
                            if curl -s -f http://localhost:${APP_PORT}/health > /dev/null; then
                                echo "✅ Application is healthy!"
                                break
                            fi
                            echo "Attempt $i/30: Application not ready yet..."
                            sleep 2
                        done
                        
                        # Final verification
                        curl -f http://localhost:${APP_PORT}/health || exit 1
                    """
                }
            }
        }
        
        stage('Integration Test') {
            steps {
                sh '''
                    echo "🧪 Running integration tests..."
                    curl -f http://localhost:3000/ || exit 1
                    curl -f http://localhost:3000/health || exit 1
                    
                    # Test response format
                    RESPONSE=$(curl -s http://localhost:3000/)
                    echo "Response: $RESPONSE"
                    
                    # Check if response contains expected fields
                    echo "$RESPONSE" | grep -q "message" && echo "✅ Message field found"
                    echo "$RESPONSE" | grep -q "status" && echo "✅ Status field found"
                '''
            }
        }
    }
    
    post {
        success {
            echo "🎉 Pipeline completed successfully!"
            script {
                currentBuild.description = "✅ Build ${env.BUILD_NUMBER} - ${GIT_COMMIT}"
                
                // Create deployment report
                sh """
                    echo "=== Deployment Report ===" > deployment-report.txt
                    echo "Application: ${APP_NAME}" >> deployment-report.txt
                    echo "Version: ${env.BUILD_NUMBER}" >> deployment-report.txt
                    echo "Commit: ${GIT_COMMIT}" >> deployment-report.txt
                    echo "Deployed at: \$(date)" >> deployment-report.txt
                    echo "URL: http://localhost:${APP_PORT}" >> deployment-report.txt
                    echo "Health Check: http://localhost:${APP_PORT}/health" >> deployment-report.txt
                    echo "" >> deployment-report.txt
                    echo "Docker Images:" >> deployment-report.txt
                    docker images | grep ${APP_NAME} >> deployment-report.txt
                """
                
                archiveArtifacts artifacts: 'deployment-report.txt'
            }
        }
        
        failure {
            echo "❌ Pipeline failed!"
            script {
                currentBuild.description = "❌ Build ${env.BUILD_NUMBER} - FAILED"
            }
        }
        
        always {
            echo "🧹 Performing cleanup..."
            
            // Clean up test containers
            sh '''
                docker ps -aq --filter "name=${APP_NAME}-test" | xargs -r docker rm -f || true
                docker ps -aq --filter "status=exited" | xargs -r docker rm || true
                docker images -q -f "dangling=true" | xargs -r docker rmi || true
            '''
            
            // Clean workspace
            cleanWs()
        }
    }
}
