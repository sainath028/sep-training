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
        
    }
}
