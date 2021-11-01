package lambdafun

import (
	"empatica-assignment/db"
	"empatica-assignment/httpError"
	"empatica-assignment/model"
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/events"
)

func HandlePostRequest(req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	log.New(os.Stderr, "Start POST /task", log.Llongfile)

	if req.Headers["content-type"] != "application/json" && req.Headers["Content-Type"] != "application/json" {
		log.New(os.Stderr, "Invalid Headers", log.Llongfile)
		return httpError.ClientError(http.StatusNotAcceptable)
	}

	tsk := new(model.Task)
	err := json.Unmarshal([]byte(req.Body), tsk)
	if err != nil {
		log.New(os.Stderr, "Invalid Body", log.Llongfile)
		return httpError.ClientError(http.StatusUnprocessableEntity)
	}

	err = db.AddTask(tsk)
	if err != nil {
		log.New(os.Stderr, "Error adding task to db", log.Llongfile)
		return httpError.ServerError(err)
	}

	log.New(os.Stderr, "END POST /task successfully", log.Llongfile)
	return events.APIGatewayProxyResponse{
		IsBase64Encoded: true,
		StatusCode:      201,
		Headers:         map[string]string{"outcome": "ok"},
	}, nil
}
