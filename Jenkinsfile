pipeline {
    agent any

    // GitHub push webhook -> start this pipeline automatically
    triggers {
        githubPush()
    }

    options {
        disableConcurrentBuilds()      // queue pushes instead of running two deploys at once
        timestamps()
    }

    environment {
        DOCKER_IMAGE = 'ahmedrehman007/midterm-model'   // Docker Hub repo (same name every build)
        CONTAINER    = 'midterm-api'
        VENV         = '/var/lib/jenkins/midterm-venv'
        SENDER       = 'ahmedrehman47555@gmail.com'
    }

    stages {
        stage('Fetch latest data') {
            steps {
                checkout scm
                script {
                    env.STUDENT_ID = sh(returnStdout: true,
                        script: "python3 -c \"import json;print(json.load(open('config.json'))['student_id'])\"").trim()
                    env.COMMIT_SHA = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                    env.COMMITTER_EMAIL = sh(returnStdout: true, script: 'git log -1 --format=%ae').trim()
                }
                sh 'echo "Student: $STUDENT_ID  Commit: $COMMIT_SHA  By: $COMMITTER_EMAIL" && wc -l dataset/train.csv'
            }
        }

        stage('Install dependencies') {
            steps {
                sh '''
                    [ -d "$VENV" ] || python3 -m venv "$VENV"
                    . "$VENV/bin/activate"
                    pip install -q --upgrade pip
                    pip install -q -r requirements.txt pytest httpx
                '''
            }
        }

        stage('Train model') {
            steps {
                sh '''
                    . "$VENV/bin/activate"
                    GIT_COMMIT="$COMMIT_SHA" python train.py
                    cat artifacts/metrics.json
                '''
            }
        }

        stage('Run tests') {
            steps {
                sh '''
                    . "$VENV/bin/activate"
                    python -m pytest -v tests
                '''
            }
        }

        stage('Build Docker image') {
            steps {
                sh 'docker build -t $DOCKER_IMAGE:latest .'
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                                  usernameVariable: 'DH_USER',
                                                  passwordVariable: 'DH_PASS')]) {
                    sh '''
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
                        docker push $DOCKER_IMAGE:latest     # replaces the previous :latest on Docker Hub
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy on EC2') {
            steps {
                sh '''
                    docker pull $DOCKER_IMAGE:latest
                    docker rm -f $CONTAINER || true
                    docker run -d --name $CONTAINER --restart always -p 8000:8000 $DOCKER_IMAGE:latest

                    # wait until the new API answers
                    for i in $(seq 1 30); do
                        if curl -sf http://localhost:8000/metrics; then echo; echo "Deployed OK"; exit 0; fi
                        sleep 2
                    done
                    echo "API did not come up"; docker logs $CONTAINER; exit 1
                '''
                // remove the old, now-untagged images so only the latest remains
                sh 'docker image prune -f || true'
            }
        }
    }

    post {
        always {
            script {
                def metrics = fileExists('artifacts/metrics.json') ? readFile('artifacts/metrics.json') : 'metrics not available'
                emailext(
                    to: env.COMMITTER_EMAIL,
                    from: env.SENDER,
                    subject: "MIDTERM ${env.STUDENT_ID} - Build #${env.BUILD_NUMBER} ${currentBuild.currentResult}: model retrained and redeployed",
                    body: """Student Reg No: ${env.STUDENT_ID}
Job: ${env.JOB_NAME}  Build #${env.BUILD_NUMBER}
Result: ${currentBuild.currentResult}
Commit: ${env.COMMIT_SHA} by ${env.COMMITTER_EMAIL}

New data was pushed to GitHub, the model was retrained, pushed to Docker Hub
(${env.DOCKER_IMAGE}:latest) and redeployed on AWS EC2.

Metrics:
${metrics}

Build log: ${env.BUILD_URL}console
""",
                    mimeType: 'text/plain'
                )
            }
        }
    }
}
