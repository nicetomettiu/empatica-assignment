package httpError

import (
	"log"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/events"
)

func ServerError(err error) (events.APIGatewayProxyResponse, error) {
	log.New(os.Stderr, "ERROR ", log.Llongfile)

	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusInternalServerError,
		Body:       http.StatusText(http.StatusInternalServerError),
	}, nil
}

func ClientError(status int) (events.APIGatewayProxyResponse, error) {
	log.New(os.Stderr, "ERROR ", log.Llongfile)

	return events.APIGatewayProxyResponse{
		StatusCode: status,
		Body:       http.StatusText(status),
	}, nil
}
