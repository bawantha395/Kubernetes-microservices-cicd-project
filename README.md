# Sample Game 01 Backend

A production-ready Spring Boot application with MySQL database, containerized with Docker, and deployed using AWS ECS with comprehensive CI/CD pipeline.

## 🚀 Features

- **Spring Boot 2.6.7** with Java 17
- **MySQL 8.0** database with JPA/Hibernate
- **JWT Authentication** with Spring Security
- **Docker** containerization
- **AWS ECS Fargate** deployment
- **Terraform** infrastructure as code
- **GitHub Actions** CI/CD pipeline
- **Comprehensive testing** and quality gates
- **Security scanning** and vulnerability detection
- **Multi-environment** support (dev, staging, prod)

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub        │    │   AWS ECS       │    │   AWS RDS       │
│   Actions       │───▶│   Fargate       │───▶│   MySQL         │
│   CI/CD         │    │   Containers    │    │   Database      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Code Quality  │    │   Application   │    │   CloudWatch    │
│   & Security    │    │   Load Balancer │    │   Monitoring    │
│   Scanning      │    │   (ALB)         │    │   & Logs       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- **Docker** and **Docker Compose** installed
- **Java 17** and **Maven** (for local development)
- **AWS CLI** and **Terraform** (for cloud deployment)

### Option 1: Local Development with Docker

```bash
# Clone the repository
git clone https://github.com/your-username/sample-game-backend.git
cd sample-game-backend

# Build and start all services
docker-compose up --build

# Or run in detached mode
docker-compose up --build -d
```

### Option 2: Local Development (Java + Maven)

```bash
# Run tests
./mvnw test

# Package the application
./mvnw clean package
```

### Option 3: Cloud Deployment

The project is fully automated via GitHub Actions. Push your changes to the `develop` or `prod` branch to trigger a deployment.

## 🔧 CI/CD Pipeline

This project includes a simplified CI/CD pipeline with:

### **Automated Testing**
- Unit tests with JUnit 5
- Integration tests with MySQL
- Basic build verification

### **Multi-Environment Deployment**
- **Development**: Automatic deployment on `develop` branch
- **Production**: Automatic deployment on `main` branch
- **Infrastructure as Code**: Terraform-managed AWS resources

## 📊 Services & Endpoints

### **Application Services**
- **App**: Spring Boot application (port 8080)
- **MySQL**: Database (port 3306)
- **Load Balancer**: AWS Application Load Balancer

### **API Endpoints**
- `GET /api/v1/application/version` - Application version
- `POST /api/v1/player/signup` - Player registration
- `PATCH /api/v1/player/account/verify` - Email verification
- `POST /api/v1/player/game/start` - Start new game
- `POST /api/v1/player/game/answer` - Submit answer
- `GET /api/v1/player/game/leaderboard` - Top scores

### **Environment Variables**

#### Local Development
```bash
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_DB=game_db
MYSQL_USER=root
MYSQL_PASS=12345
```

#### Cloud Deployment
```bash
MYSQL_HOST=${RDS_ENDPOINT}
MYSQL_PORT=3306
MYSQL_DB=game_db
MYSQL_USER=${DB_USERNAME}
MYSQL_PASS=${DB_PASSWORD}
SPRING_PROFILES_ACTIVE=prod
```

## 🛠️ Development

### **Project Structure**
```
backend/
├── src/main/java/           # Java source code
├── src/main/resources/      # Configuration files
├── src/test/java/           # Test code
├── .github/workflows/       # GitHub Actions
├── terraform/               # Infrastructure as code (environment-aware)
└── docker-compose.yml       # Local development
```

### **Running Tests**
```bash
# Run all tests
./mvnw test

# Run with coverage
./mvnw test jacoco:report

# Run specific test
./mvnw test -Dtest=GameServiceTest
```

### **Basic Build and Test**
```bash
# Run tests
./mvnw test

# Build application
./mvnw clean package

# Run with specific profile
./mvnw clean package -Pprod
```

## 🚀 Deployment

### **Development Environment**
```bash
# Automatic deployment on push to develop branch
git push origin develop
```

### **Production Environment**
```bash
# Automatic deployment on push to main branch
git push origin prod
```

### **Automated Infrastructure Actions**
Manual actions (like `destroy`) can be triggered through the "Actions" tab in the GitHub repository.

## 📈 Monitoring & Observability

### **Application Monitoring**
- **Health Checks**: `/api/v1/application/version`
- **Metrics**: CPU, memory, request count, error rate
- **Logs**: Centralized logging with CloudWatch

### **Infrastructure Monitoring**
- **ECS Service Health**: Service status, task count
- **RDS Monitoring**: Database performance, connections
- **ALB Health**: Load balancer health, target health

### **Alerts**
- High CPU/Memory usage
- Error rate thresholds
- Database connection issues
- Deployment failures

## 🔒 Security

### **Security Features**
- JWT-based authentication
- Rate limiting and throttling
- Input validation and sanitization
- SQL injection prevention
- XSS protection
- CORS configuration
- Security headers

## 📚 Documentation

- [CI/CD Setup Guide](docs/CI-CD-SETUP.md) - Comprehensive CI/CD setup instructions
- [API Documentation](docs/API.md) - API endpoint documentation
- [Deployment Guide](docs/DEPLOYMENT.md) - Deployment instructions
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions

## 🆘 Support

### **Getting Help**
1. Check the [troubleshooting guide](docs/TROUBLESHOOTING.md)
2. Review GitHub Actions logs
3. Check AWS CloudWatch logs
4. Create an issue in the repository

### **Common Issues**
- **Build failures**: Check Maven dependencies and Docker daemon
- **Deployment issues**: Verify AWS credentials and Terraform state
- **Database issues**: Check RDS instance and security groups
- **Application issues**: Review CloudWatch logs

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and quality checks
5. Create a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built with ❤️ using Spring Boot, Docker, AWS, and GitHub Actions**




how to run after deployed


aws eks list-clusters

aws eks update-kubeconfig --region us-east-1 --name <your-cluster-name>
aws eks update-kubeconfig --region us-east-1 --name prod-prod-issue-app-cluster


Install Argo CD

# Create the namespace
kubectl create namespace argocd

# Install Argo CD using the official stable manifests
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

Re-install the External Secrets Operator
helm install external-secrets external-secrets/external-secrets \
-n issue-app \
--create-namespace \
--set webhook.port=9443

Apply your Argo CD Application File
kubectl apply -f application-prod.yaml

Verify everything works
kubectl get app issue-app-prod -n argocd



acess to argocd ui
kubectl port-forward svc/argocd-server -n argocd 8080:443

usename admin
get argo password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode; echo


go to https://localhost:8080
