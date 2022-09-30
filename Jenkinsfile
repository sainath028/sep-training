pipeline {
    agent any

    stages {
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
