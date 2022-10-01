pipeline {
    agent any
    parameters {
        choice(
            name: 'SERVER',
            choices: ['dev', 'qa','uat', 'prod'],
            description: ''
        )
    }
    stages {
        stage('maven') {
            steps {
                    sh 'mvn clean install -DskipTests' 
            }
        }

        stage('ansible') {
            steps {
                    sh 'chmod 400 SEP_trainning.pem'
                    sh 'ansible-playbook -i hosts tomcat.yaml --extra-vars "server=$SERVER job-name=$JOB_NAME"' 
            }
        }

    }
}
