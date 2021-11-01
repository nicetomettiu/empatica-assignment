package lambdafun

import (
	"context"
	"empatica-assignment/db"
	"empatica-assignment/httpError"
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/events"
)

func HandleGetRequest(ctx context.Context) (events.APIGatewayProxyResponse, error) {
	log.New(os.Stderr, "Start GET /tasks", log.Llongfile)
	tasks, err := db.GetTasks(ctx)
	if err != nil {
		log.New(os.Stderr, "Error retrieving tasks", log.Llongfile)
		return httpError.ServerError(err)
	}
	if tasks == nil {
		log.New(os.Stderr, "No tasks found", log.Llongfile)
		return httpError.ClientError(http.StatusNotFound)
	}

	res, err := json.Marshal(tasks)
	if err != nil {
		log.New(os.Stderr, "Error marshalling tasks", log.Llongfile)
		return httpError.ServerError(err)
	}

	log.New(os.Stderr, "END GET /tasks successfully", log.Llongfile)
	return events.APIGatewayProxyResponse{
		Headers:         map[string]string{"outcome": "ok"},
		IsBase64Encoded: true,
		StatusCode:      http.StatusOK,
		Body:            string(res),
	}, nil
}
