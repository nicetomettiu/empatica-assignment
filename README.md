# Serverless application on AWS + Elasticsearch - Empatica Assignment Challenge 2

Serverless application on AWS consisting in two endpoints:
- GET /tasks to retrieve all tasks
- POST /task to create a new task, with HTTP basic authentication

The endpoints and the gateway authorizer are implemented as lambda functions in golang.

Data is stored in a dynamodb instance.

All AWS resource are created using Terraform infrastructure.


## Quickstart

This project uses:

- [Terraform](https://www.terraform.io)
- [Go 1.17](https://golang.org/)

## Project build - Golang

First thing you need to do is generate the lambda funcions binaires, that will be zipped to store the source code on a S3 bucket by terraform:

```console
$ GOOS=linux GOARCH=amd64 CGO_ENALBED=0 go build -o ./target/lambdagetbin -ldflags '-w' ./handlers/getTasks/main.go
$ GOOS=linux GOARCH=amd64 CGO_ENALBED=0 go build -o ./target/lambdapostbin -ldflags '-w' ./handlers/postTask/main.go
$ GOOS=linux GOARCH=amd64 CGO_ENALBED=0 go build -o ./target/lambdasuthbin -ldflags '-w' ./handlers/auth/main.go
```

## AWS resource creation and deployment - Terraform

Finally to generate all AWS resources (S3 bucket, api gateway, authorizer, lambda functions, dyanomoDB and cloud watch log on elastic search), run the command:

```console
$ terraform init
$ terraform apply
```

