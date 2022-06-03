name: OnPushIntoAllBranches

on:
  push:
    branches:
      - '*'         # matches every branch that doesn't contain a '/'
      - '*/*'       # matches every branch containing a single '/'
      - '**'        # matches every branch
      - '!master'   # excludes master

env:
  RR_VERSION: 2.9.4
  PHP_IMAGE_VERSION: 8.1-cli-alpine

jobs:
  laravel-tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Create .env
      run: cp .env.testing .env
    - name: Pull images
      run: docker-compose -f docker-compose.ci.yml pull --ignore-pull-failures || true
    - name: Start services
      run: docker-compose -f docker-compose.ci.yml up --build -d
    - name: Wait for services
      run: |
        while status="$(docker inspect --format="{{if .Config.Healthcheck}}{{print .State.Health.Status}}{{end}}" "$(docker-compose -f docker-compose.ci.yml ps -q roadrunner)")"; do
          case $status in
            starting) sleep 5;;
            healthy) exit 0;;
            unhealthy)
              docker-compose -f docker-compose.ci.yml ps
              sleep 5
            ;;
          esac
        done
        exit 0
# docker-compose -f docker-compose.ci.yml logs
#    - name: Install Dependencies
#      run: docker-compose exec -T composer install --no-dev --no-interaction --prefer-dist --ignore-platform-reqs --optimize-autoloader --apcu-autoloader --ansi --no-scripts
    - name: Directory Permissions
      run: docker-compose -f docker-compose.ci.yml exec -T chmod -R 777 storage bootstrap/cache roadrunner
    - name: Refresh composer dump
      run: docker-compose -f docker-compose.ci.yml exec -T composer dumpautoload roadrunner
    - name: code analise
      run: docker-compose -f docker-compose.ci.yml exec -T ./vendor/bin/phpstan analyse --memory-limit=2G roadrunner
