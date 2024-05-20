package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
    "strings"
	"github.com/aws/aws-lambda-go/lambda"
	"io"
	"log"
	"net/http"
	"os"
	"fmt"
	"context"
)

func HandleRequest(ctx context.Context, event interface{}) (string, error) {
	fmt.Println("event", event)

	return "Hello world", nil
}

func createJSON(msg string, status int) ([]byte, error) {
	data := map[string]interface{}{
		"msg":    msg,
		"status": status,
	}
	return json.Marshal(data)
}

func server() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		query := r.URL.Query()
		method := query.Get("method")
		if method == "" {
			method = "post"
		}
        method = strings.ToUpper(method)
		encoding := query.Get("encoding")
		if encoding == "" {
			encoding = "none"
		}
		target := query.Get("target")
		if target == "" {
			resp, _ := createJSON("No target set", http.StatusBadRequest)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadRequest)
			w.Write(resp)
			log.Printf("No target set")
			return
		}
		data := query.Get("data")
		if data == "" {
			resp, _ := createJSON("No data sent", http.StatusBadRequest)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadRequest)
			w.Write(resp)
			log.Printf("No data sent")
			return
		}

		if encoding == "base64" {
			decodedData, err := base64.StdEncoding.DecodeString(data)
			if err != nil {
				resp, _ := createJSON("Error decoding base64", http.StatusBadRequest)
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusBadRequest)
				w.Write(resp)
				log.Println("Error decoding base64:", err)
				return
			}
			data = string(decodedData)

		}
		req, err := http.NewRequest(method, target, bytes.NewBuffer([]byte(data)))
		if err != nil {
            log.Fatalln(err)
		}

        log.Printf("Sending %s request to: %s",method, target)
		client := &http.Client{}
		resp, err := client.Do(req)
		if err != nil {
			log.Fatalln(err)
		}
		defer resp.Body.Close()

		_, err = io.Copy(w, resp.Body)
		if err != nil {
			log.Fatalln(err)
		}
	})
	port := os.Getenv("PORT")
	if port == "" {
		port = "3000"
	}
	log.Printf("Starting server on :%s\n", port)

	http.ListenAndServe(":"+port, nil)
}

func main() {
	if os.Getenv("SSH_AUTH_SOCK") != "" {
		server()
	} else {
		lambda.Start(HandleRequest)
	}
}
