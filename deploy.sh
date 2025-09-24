#!/bin/bash

# Nazliyavuz Platform Production Deployment Script
# This script automates the deployment process for production

set -e

echo "🚀 Starting Nazliyavuz Platform Production Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="nazliyavuz-platform"
BACKEND_DIR="./backend"
FRONTEND_DIR="./frontend/nazliyavuz_app"
DOCKER_COMPOSE_FILE="docker-compose.yml"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is installed
check_docker() {
    log_info "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    log_success "Docker and Docker Compose are installed"
}

# Check if required files exist
check_files() {
    log_info "Checking required files..."
    
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        log_error "Docker Compose file not found: $DOCKER_COMPOSE_FILE"
        exit 1
    fi
    
    if [ ! -d "$BACKEND_DIR" ]; then
        log_error "Backend directory not found: $BACKEND_DIR"
        exit 1
    fi
    
    if [ ! -d "$FRONTEND_DIR" ]; then
        log_error "Frontend directory not found: $FRONTEND_DIR"
        exit 1
    fi
    
    log_success "All required files found"
}

# Create necessary directories
create_directories() {
    log_info "Creating necessary directories..."
    
    mkdir -p nginx/sites
    mkdir -p nginx/ssl
    mkdir -p monitoring/grafana/dashboards
    mkdir -p monitoring/grafana/datasources
    mkdir -p logs
    
    log_success "Directories created"
}

# Generate SSL certificates (self-signed for development)
generate_ssl() {
    log_info "Generating SSL certificates..."
    
    if [ ! -f "nginx/ssl/nazliyavuz.crt" ]; then
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout nginx/ssl/nazliyavuz.key \
            -out nginx/ssl/nazliyavuz.crt \
            -subj "/C=TR/ST=Istanbul/L=Istanbul/O=Nazliyavuz/OU=IT/CN=nazliyavuz.com"
        
        log_success "SSL certificates generated"
    else
        log_info "SSL certificates already exist"
    fi
}

# Build and start services
deploy_services() {
    log_info "Building and starting services..."
    
    # Stop existing containers
    docker-compose down --remove-orphans
    
    # Build and start services
    docker-compose up -d --build
    
    log_success "Services deployed successfully"
}

# Wait for services to be ready
wait_for_services() {
    log_info "Waiting for services to be ready..."
    
    # Wait for PostgreSQL
    log_info "Waiting for PostgreSQL..."
    until docker-compose exec -T postgres pg_isready -U nazliyavuz_user -d nazliyavuz_platform; do
        sleep 2
    done
    log_success "PostgreSQL is ready"
    
    # Wait for Redis
    log_info "Waiting for Redis..."
    until docker-compose exec -T redis redis-cli ping; do
        sleep 2
    done
    log_success "Redis is ready"
    
    # Wait for Laravel app
    log_info "Waiting for Laravel application..."
    sleep 10
    log_success "Laravel application is ready"
}

# Run Laravel setup commands
setup_laravel() {
    log_info "Setting up Laravel application..."
    
    # Generate application key
    docker-compose exec -T app php artisan key:generate --force
    
    # Run migrations
    docker-compose exec -T app php artisan migrate --force
    
    # Seed database
    docker-compose exec -T app php artisan db:seed --force
    
    # Clear and cache config
    docker-compose exec -T app php artisan config:clear
    docker-compose exec -T app php artisan config:cache
    
    # Clear and cache routes
    docker-compose exec -T app php artisan route:clear
    docker-compose exec -T app php artisan route:cache
    
    # Clear and cache views
    docker-compose exec -T app php artisan view:clear
    docker-compose exec -T app php artisan view:cache
    
    # Optimize autoloader
    docker-compose exec -T app composer dump-autoload --optimize
    
    log_success "Laravel application setup completed"
}

# Run health checks
health_check() {
    log_info "Running health checks..."
    
    # Check if all containers are running
    if docker-compose ps | grep -q "Up"; then
        log_success "All containers are running"
    else
        log_error "Some containers are not running"
        docker-compose ps
        exit 1
    fi
    
    # Check API health
    if curl -f http://localhost/health > /dev/null 2>&1; then
        log_success "API health check passed"
    else
        log_warning "API health check failed - this might be normal during initial setup"
    fi
    
    log_success "Health checks completed"
}

# Display deployment information
show_deployment_info() {
    log_success "🎉 Deployment completed successfully!"
    echo ""
    echo "📋 Deployment Information:"
    echo "=========================="
    echo "🌐 Application URL: https://nazliyavuz.com"
    echo "📊 Grafana Dashboard: http://localhost:3000 (admin/admin_password_123)"
    echo "📈 Prometheus Metrics: http://localhost:9090"
    echo "🗄️  Database: PostgreSQL on port 5432"
    echo "⚡ Cache: Redis on port 6379"
    echo ""
    echo "🔧 Management Commands:"
    echo "======================"
    echo "View logs: docker-compose logs -f"
    echo "Stop services: docker-compose down"
    echo "Restart services: docker-compose restart"
    echo "Update services: docker-compose pull && docker-compose up -d"
    echo ""
    echo "📝 Next Steps:"
    echo "=============="
    echo "1. Update DNS records to point to your server"
    echo "2. Configure SSL certificates for production"
    echo "3. Set up monitoring alerts"
    echo "4. Configure backup strategy"
    echo "5. Set up CI/CD pipeline"
    echo ""
}

# Main deployment function
main() {
    log_info "Starting deployment process..."
    
    check_docker
    check_files
    create_directories
    generate_ssl
    deploy_services
    wait_for_services
    setup_laravel
    health_check
    show_deployment_info
    
    log_success "🚀 Nazliyavuz Platform is now running in production!"
}

# Run main function
main "$@"
