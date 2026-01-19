pipeline {
    agent any
    
    environment {
        // Versioning
        APP_NAME = 'sample-app'
        VERSION = "${env.BUILD_NUMBER}"
        
        // SonarQube
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_AUTH_TOKEN = credentials('sonarqube-token')  // Jenkins credential ID
        
        // Docker
        DOCKER_REGISTRY = 'localhost:5000'
        DOCKER_IMAGE = "${APP_NAME}"
        DOCKER_TAG = "${VERSION}"
        
        // Application
        NODE_ENV = 'production'
        PORT = '3000'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        ansiColor('xterm')
    }
    
    tools {
        nodejs 'nodejs-18'  // Configure in Jenkins Global Tools
    }
    
    stages {
        stage('Initialize') {
            steps {
                script {
                    echo "Starting pipeline for ${APP_NAME}"
                    echo "Build Number: ${VERSION}"
                    echo "Branch: ${env.GIT_BRANCH}"
                    
                    // Create build info file
                    sh """
                        echo "Build ${VERSION}" > build-info.txt
                        echo "Date: \$(date)" >> build-info.txt
                        echo "Commit: \$(git rev-parse HEAD)" >> build-info.txt
                    """
                }
            }
        }
        
        stage('Checkout') {
            steps {
                checkout scm
                // Or for local repository:
                // dir('workspace') {
                //     sh 'cp -r /home/ubuntu/sample-app/* .'
                // }
            }
        }
        
        stage('Install Dependencies') {
            steps {
                sh 'npm ci --prefer-offline'
            }
        }
        
        stage('Code Quality') {
            parallel {
                stage('Linting') {
                    steps {
                        sh 'npm run lint || true'  // Continue even if linting fails
                    }
                    post {
                        always {
                            recordIssues(
                                tools: [esLint(pattern: '**/eslint-report.json')],
                                enabledForFailure: true
                            )
                        }
                    }
                }
                
                stage('Security Audit') {
                    steps {
                        sh 'npm audit --audit-level=moderate || true'
                    }
                }
            }
        }
        
        stage('Unit Tests') {
            steps {
                sh 'npm test -- --coverage'
            }
            post {
                always {
                    junit '**/test-results.xml'
                    publishHTML(target: [
                        reportDir: 'coverage/lcov-report',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh """
                        sonar-scanner \
                          -Dsonar.projectKey=${APP_NAME} \
                          -Dsonar.projectName="${APP_NAME}" \
                          -Dsonar.projectVersion=${VERSION} \
                          -Dsonar.sources=. \
                          -Dsonar.exclusions=**/node_modules/**,**/coverage/** \
                          -Dsonar.tests=test \
                          -Dsonar.test.inclusions=**/*.test.js \
                          -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info \
                          -Dsonar.qualitygate.wait=true
                    """
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    // Check Docker daemon
                    sh 'docker --version'
                    
                    // Build image
                    dockerImage = docker.build(
                        "${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}",
                        "--build-arg NODE_ENV=${NODE_ENV} ."
                    )
                    
                    // Tag as latest
                    sh "docker tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest"
                }
            }
        }
        
        stage('Test Docker Image') {
            steps {
                script {
                    // Run container tests
                    sh """
                        docker run --rm \
                          --name ${APP_NAME}-test \
                          ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} \
                          npm test
                    """
                    
                    // Test health endpoint
                    sh """
                        docker run -d --rm \
                          --name ${APP_NAME}-healthcheck \
                          -p 3001:3000 \
                          ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}
                        
                        sleep 10
                        curl -f http://localhost:3001/health || exit 1
                        docker stop ${APP_NAME}-healthcheck
                    """
                }
            }
        }
        
        stage('Push to Registry') {
            when {
                branch 'main'
            }
            steps {
                script {
                    docker.withRegistry("http://${DOCKER_REGISTRY}") {
                        dockerImage.push()
                        dockerImage.push('latest')
                    }
                    echo "Image pushed: ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}"
                }
            }
        }
        
        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "Deploying ${APP_NAME}:${DOCKER_TAG}"
                    
                    // Create docker-compose.prod.yml
                    writeFile file: 'docker-compose.prod.yml', text: """
version: '3.8'
services:
  ${APP_NAME}:
    image: ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}
    container_name: ${APP_NAME}
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - PORT=3000
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
"""
                    
                    // Deploy using docker-compose
                    sh """
                        # Stop and remove old container
                        docker-compose -f docker-compose.prod.yml down || true
                        
                        # Pull latest image
                        docker pull ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}
                        
                        # Start new container
                        docker-compose -f docker-compose.prod.yml up -d
                        
                        # Wait for health check
                        sleep 15
                        curl -f http://localhost:3000/health || exit 1
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo "Pipeline completed successfully!"
            script {
                currentBuild.description = "✓ ${VERSION}"
                
                // Send notification
                slackSend(
                    channel: '#deployments',
                    color: 'good',
                    message: "✅ Deployment Successful\n" +
                            "Project: ${APP_NAME}\n" +
                            "Version: ${VERSION}\n" +
                            "URL: http://localhost:3000\n" +
                            "Build: ${env.BUILD_URL}"
                )
            }
        }
        failure {
            echo "Pipeline failed!"
            script {
                currentBuild.description = "✗ ${VERSION}"
                
                slackSend(
                    channel: '#deployments',
                    color: 'danger',
                    message: "❌ Deployment Failed\n" +
                            "Project: ${APP_NAME}\n" +
                            "Version: ${VERSION}\n" +
                            "Build: ${env.BUILD_URL}\n" +
                            "Console: ${env.BUILD_URL}console"
                )
            }
        }
        unstable {
            echo "Pipeline unstable (SonarQube Quality Gate failed)"
        }
        always {
            echo "Cleaning up..."
            
            // Clean Docker resources
            sh '''
                # Remove dangling images
                docker image prune -f
                
                # Remove stopped containers
                docker container prune -f
                
                # Clean workspace
                docker system df
            '''
            
            // Archive artifacts
            archiveArtifacts artifacts: 'build-info.txt,package.json'
            
            // Clean workspace
            cleanWs()
        }
    }
}
