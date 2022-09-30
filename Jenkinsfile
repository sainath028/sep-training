pipeline {
    agent any

    stages {
        stage('git clone') {
            steps {
                dir('profilelogin'){
                    git branch: 'master', url: "https://github.com/sainath028/vprofile-repo.git" 
                }
                dir('ravilogin'){
                    git branch: 'master', url: "https://github.com/sainath028/raviLogin.git" 
                }
            }
        }

        stage('maven') {
            steps {
                dir('profilelogin'){
                    sh 'mvn clean install -DskipTests' 
                }
                dir('ravilogin'){
                    sh 'mvn clean install -DskipTests'   
                }
            }
        }
        stage('archive') {
            steps {
                dir('profilelogin'){
                    archiveArtifacts artifacts: 'target/vprofile-v1.war', followSymlinks: false   
                }
                dir('ravilogin'){
                    archiveArtifacts artifacts: 'target/raviLogin-1.0.war', followSymlinks: false       
                }
            }
        }

    }
}
