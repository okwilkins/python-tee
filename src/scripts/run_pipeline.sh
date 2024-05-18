#! /bin/bash
# run_pipeline.sh

# Pick the correct Python command
if command -v python3 &> /dev/null; then
    PYTHON=python3
elif command -v python &> /dev/null; then
    PYTHON=python
else
    echo "Python not found"
    exit 1
fi

wikipedia_data=$(curl -L -s "https://en.wikipedia.org/api/rest_v1/page/random/summary")
text_to_embed=$(jq -r ".title, .description, .extract" <(echo $wikipedia_data))

embedding_data=$(
    echo $text_to_embed | \
    $PYTHON ./src/app/main.py embed --ollama-url localhost:11434 2>> output.log
)

payload_data=$(jq "{title: .title, description: .description, extract: .extract}" <(echo $wikipedia_data))

echo $(jq -r ".embedding" <(echo $embedding_data)) | \
$PYTHON ./src/app/main.py vector-store \
    --qdrant-url http://localhost:6333 \
    --collection-name nomic-embed-text-v1.5 \
    --data "$payload_data" \
    2>> output.log

if [ $? -ne 0 ]; then
    echo "Failed to store the embedding in Qdrant. | $(date +"%Y-%m-%d %H:%M:%S.%3N") | Wikipedia article: $(jq -r ".title" <(echo $payload_data))"
    exit 1
else 
    echo "Embedding stored in Qdrant. | $(date +"%Y-%m-%d %H:%M:%S.%3N") | Wikipedia article: $(jq -r ".title" <(echo $payload_data))"
fi
