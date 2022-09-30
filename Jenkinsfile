pipeline {
    agent any

    stages {
        stage('git clone') {
            steps {
                    git branch: 'master', url: "https://github.com/sainath028/vprofile-repo.git" 
                }
        }

        stage('maven') {
            steps {
                    sh 'mvn clean install -DskipTests' 
            }
        }

        stage('ansible') {
            steps {
                    sh 'ansible-playbook -i hosts tomcat.yaml' 
            }
        }

    }
}
