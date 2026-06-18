#!/bin/bash

set -e

echo "🚀 Deploying Flint Application with Docker..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ ERROR: .env file not found${NC}"
    echo -e "${YELLOW}Please make sure you have an .env file in the project root${NC}"
    exit 1
fi

echo -e "${GREEN}📁 Using your existing .env configuration${NC}"

APP_PORT=$(grep -E '^PORT=' .env | tail -n 1 | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ')
if [ -z "$APP_PORT" ]; then
    APP_PORT="3030"
fi

# Stop existing containers
echo -e "${YELLOW}🛑 Stopping existing services...${NC}"
docker-compose down

# Build and start
echo -e "${YELLOW}🐳 Building and starting services...${NC}"
docker-compose up -d --build

# Wait for services to be healthy
echo -e "${YELLOW}⏳ Waiting for services to be ready...${NC}"
sleep 15

# Check if services are running
if docker-compose ps | grep -q "Up"; then
    echo -e "${GREEN}✅ Deployment successful!${NC}"
    echo ""
    echo -e "${GREEN}🌐 Your application is running at:${NC}"
    echo -e "   • API: http://localhost:$APP_PORT"
    echo ""
    echo -e "${YELLOW}🔍 View logs: ${NC}docker-compose logs -f"
    echo -e "${YELLOW}🛑 Stop services: ${NC}docker-compose down"
else
    echo -e "${RED}❌ Some services failed to start${NC}"
    echo -e "${YELLOW}🔍 Check logs: ${NC}docker-compose logs"
    exit 1
fi
