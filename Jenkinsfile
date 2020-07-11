library 'magic-butler-catalogue'
def PROJECT_NAME = 'logdna-agent-v2'

pipeline {
    agent {
        docker {
            image 'rust:1.44'
        }
    }
    options {
        timestamps()
        ansiColor 'xterm'
    }
    stages {
        stage('Prepare Environment') {
            steps {
                sh 'rustup update'
                sh 'rustup component add clippy'
                sh 'rustup component add rustfmt'
            }
        }
        stage('Test') {
            steps {
                sh 'make test'
            }
        }
        stage('Clean') {
            steps {
                sh 'make clean'
            }
        }
        stage('Build') {
            steps {
                sh 'RELEASE=1 make build'
            }
        }
    }
}
