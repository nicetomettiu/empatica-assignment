package main

import (
	"empatica-assignment/lambdafun"

	"github.com/aws/aws-lambda-go/lambda"
)

func main() {
	lambda.Start(lambdafun.HandleGetRequest)
}
