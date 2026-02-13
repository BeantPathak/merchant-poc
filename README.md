Install prerequisites

Docker + LocalStack

docker run -d --name localstack \
  -p 4566:4566 -p 4510-4559:4510-4559 \
  -e SERVICES=lambda,stepfunctions,postgres \
  -e DEBUG=1 \
  -e DATA_DIR=/tmp/localstack/data \
  localstack/localstack


AWS CLI

Python 3.10 + pip

pg8000


localstack start

docker compose down -v

docker compose up -d


Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

.\deploy.ps1

 aws --endpoint-url http://localhost:4566 stepfunctions start-execution --state-machine-arn arn:aws:states:us-east-1:000000000000:stateMachine:merchant-onboarding --input "{}"

 aws --endpoint-url http://localhost:4566 stepfunctions get-execution-history --execution-arn arn:aws:states:us-east-1:000000000000:execution:merchant-onboarding:31111ac7-6393-4973-9257-ef56a11ccf50

