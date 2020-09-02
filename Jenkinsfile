library 'magic-butler-catalogue'
def PROJECT_NAME = 'logdna-agent-v2'
def RUST_IMAGE_REPO = 'us.gcr.io/logdna-k8s/rust'

pipeline {
    agent any
    options {
        timestamps()
        ansiColor 'xterm'
    }
    triggers {
        cron(env.BRANCH_NAME ==~ /\d\.\d/ ? 'H H 1,15 * *' : '')
    }
    stages {
        stage('Test') {
            steps {
                sh """
                    echo 'TEST' #make lint RUST_IMAGE_REPO=${RUST_IMAGE_REPO}
                    echo 'LINT' #make test RUST_IMAGE_REPO=${RUST_IMAGE_REPO}
                """
            }
            post {
                success {
                    sh "echo 'CLEAN' #make clean RUST_IMAGE_REPO=${RUST_IMAGE_REPO}"
                }
            }
        }
        stage('Build & Publish Images') {
            stages {
                stage('Build Image') {
                    steps {
                        sh "echo 'BUILD-IMAGE' #make build-image RUST_IMAGE_REPO=${RUST_IMAGE_REPO}"
                    }
                }
                stage('Check Publish Images') {
                    when {
                        branch pattern: "initial-ci-cd-test", comparator: "REGEXP"
                    }
                    stages {
                        stage('Publish Images') {
                            input {
                                message "Should we publish the versioned image?"
                                ok "Publish image"
                            }
                            steps {
			        script {
                                    docker.withRegistry('https://docker.io', 'dockerhub-username-password') {
                                        docker.withRegistry('https://icr.io', 'icr-username-password') {
                                            sh 'docker pull icr.io/ext/logdna-agent:2.1.9'
                                            sh 'docker pull docker.io/logdna/logdna-agent:2.1.9'
					}
                                    }
                                }
                            }
                        }
                    }
                }
            }
            post {
                always {
                    sh 'make clean-all'
                }
            }
        }
    }
}
