pipeline {
    agent any
	
    tools {
        nodejs "node_v1"
        maven "maven-3.6"
    }
    
    stages {
        
        
        stage ('PULL CODE') {
            
            steps {
                dir('ui') {
                    git branch: 'master', credentialsId: 'sainath', url: 'git url'
                }
               
                dir('api') {
                    git branch: 'master', credentialsId: 'sainath', url: 'git url'
                }
            }
        }

        stage ('build UI CODE') {
            steps {
                dir('ui') {
                 sh 'npm install'
                 sh 'npm run build'
                }
            }
        }
        
        stage ('Copy  UI to api') {
            steps {
                sh 'cp -Rp ui/* api/src/main/resources/static/'
            }
        }
        
        stage ('build with maven'){
            steps {
                dir('api') {
                    sh 'mvn clean install'
                    sh 'ls -l'
                    archiveArtifacts 'target/xyz.war'
                }
            }
        }
        
        stage ('Deploy Build Tomcat') {
        	steps {
        		dir('api') {
                        tomcat deployment
        			}
        		}
	       }
        }
        
    }
}
