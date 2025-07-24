#!/bin/bash

echo "Updating instance..."
sudo yum update -y

echo "Installing Java 21..."
sudo yum install -y java-21-openjdk

echo "Installing Maven..."
sudo yum install -y maven

echo "Cloning GitHub repo..."
git clone https://github.com/Trainings-TechEazy/test-repo-for-devops.git

cd test-repo-for-devops

echo "Building the project with Maven..."
mvn clean package

echo "Running the app in background..."
nohup java -jar target/hellomvc-0.0.1-SNAPSHOT.jar &

echo "Setup complete!"
