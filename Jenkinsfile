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
                    make lint RUST_IMAGE_REPO=${RUST_IMAGE_REPO}
                    make test RUST_IMAGE_REPO=${RUST_IMAGE_REPO}
                """
            }
            post {
                success {
                    sh "make clean RUST_IMAGE_REPO=${RUST_IMAGE_REPO}"
                }
            }
        }
        stage('Build & Publish Images') {
            stages {
                stage('Build Image') {
                    steps {
                        sh "make build-image RUST_IMAGE_REPO=${RUST_IMAGE_REPO}"
                    }
                }
                stage('Check Publish Images') {
                    when {
                        branch pattern: "\\d\\.\\d", comparator: "REGEXP"
                    }
                    stages {
                        stage('Publish Images') {
                            input {
                                message "Should we publish the versioned image?"
                                ok "Publish image"
                            }
                            steps {
                                withCredentials([string(credentialsId: 'icr-iamapikey', variable: 'ICR_IAMAPIKEY'), string(credentialsId: 'dockerhub-access-token', variable: 'DOCKERHUB_ACCESS_TOKEN')]) {
                                    sh '''
                                        echo "${DOCKERHUB_ACCESS_TOKEN}" | docker login -u logdna --password-stdin
                                        echo "${ICR_IAMAPIKEY}" | docker login -u iamapikey --password-stdin icr.io
                                        make publish
                                    '''
                                }
                            }
                            post {
                                always {
                                    sh '''
                                        docker logout
                                        docker logout icr.io
                                    '''
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
