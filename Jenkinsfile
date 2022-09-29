pipeline {
    agent any

    stages {
        stage('terraform init') {
            steps {
              sh "terraform init" 
            }
        }
        
        stage('terraform plan') {
            steps {
                script {
                    sh  "ls -ll"
                    sh "pwd"
                    sh "export TF_LOGS=trace"
                }
            }
        }
        
        stage('terraform apply') {
            steps {
              sh "terraform apply -no-color --auto-approve"

            }
        }
    }
}
