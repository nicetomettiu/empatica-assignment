package db

import (
	"context"
	"empatica-assignment/model"
	"log"
	"os"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
	"github.com/google/uuid"
)

var db = dynamodb.New(session.Must(session.NewSession()), aws.NewConfig().WithRegion("eu-central-1"))

func GetTasks(ctx context.Context) ([]model.Task, error) {
	log.New(os.Stderr, "Start retrieving tasks from db", log.Llongfile)

	input := &dynamodb.ScanInput{
		TableName: aws.String("Tasks"),
	}

	result, err := db.ScanWithContext(ctx, input)
	if err != nil {
		log.New(os.Stderr, "Error retrieving tasks from db", log.Llongfile)
		return nil, err
	}
	if len(result.Items) == 0 {
		log.New(os.Stderr, "No tasks found from db", log.Llongfile)
		return nil, nil
	}

	tasks := []model.Task{}

	if err := dynamodbattribute.UnmarshalListOfMaps(result.Items, &tasks); err != nil {
		log.New(os.Stderr, "Error unmarshalling tasks from db", log.Llongfile)
		return nil, err
	}

	return tasks, nil
}

func AddTask(tsk *model.Task) error {
	log.New(os.Stderr, "Adding tasks to db", log.Llongfile)
	log.New(os.Stderr, "New item:"+tsk.Task, log.Llongfile)

	id := uuid.New().String()
	input := &dynamodb.PutItemInput{
		TableName: aws.String("Tasks"),

		Item: map[string]*dynamodb.AttributeValue{
			"TaskId": {
				S: aws.String(id),
			},
			"Task": {
				S: aws.String(tsk.Task),
			},
		},
	}

	_, err := db.PutItem(input)
	return err
}
