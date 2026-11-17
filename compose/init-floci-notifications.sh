#!/bin/sh
# Floci queues for waste-obligations-notifications (obligations profile only, so other profiles don't collect
# unread analytics events). Run by the waste-obligations-notifications-init service after floci-init has created the
# analytics topic. Safe to run again: creating an existing queue or subscription returns the existing one.
set -eu

topic_arn="arn:aws:sns:eu-west-2:000000000000:waste_obligations_analytics_events"
analytics_queue="waste_obligations_notifications_analytics_events_queue"
command_queue="waste_obligations_notifications_commands.fifo"
command_dead_letter_queue="waste_obligations_notifications_commands_dlq.fifo"

queue_arn() {
    aws sqs get-queue-attributes --queue-url "$1" --attribute-names QueueArn --query "Attributes.QueueArn" --output text
}

# Sends a queue's failed messages to a dead-letter queue after 3 receives, as the CDP convention configures.
redrive_to() {
    queue_url="$1"
    dead_letter_arn="$2"

    cat > /tmp/redrive.json <<EOF
{
  "RedrivePolicy": "{\"deadLetterTargetArn\":\"$dead_letter_arn\",\"maxReceiveCount\":\"3\"}"
}
EOF
    aws sqs set-queue-attributes --queue-url "$queue_url" --attributes file:///tmp/redrive.json
    aws sqs get-queue-attributes --queue-url "$queue_url" --attribute-names RedrivePolicy \
        --query "Attributes.RedrivePolicy" --output text | grep -F "$dead_letter_arn" > /dev/null
}

# The analytics queue: subscribed to the topic with raw message delivery (the service reads raw bodies).
dead_letter_url="$(aws sqs create-queue --queue-name "${analytics_queue}-deadletter" --query QueueUrl --output text)"
queue_url="$(aws sqs create-queue --queue-name "$analytics_queue" --query QueueUrl --output text)"
queue_arn_value="$(queue_arn "$queue_url")"

cat > /tmp/policy.json <<EOF
{
  "Policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":\"sqs:SendMessage\",\"Resource\":\"$queue_arn_value\",\"Condition\":{\"ArnEquals\":{\"aws:SourceArn\":\"$topic_arn\"}}}]}"
}
EOF
aws sqs set-queue-attributes --queue-url "$queue_url" --attributes file:///tmp/policy.json
redrive_to "$queue_url" "$(queue_arn "$dead_letter_url")"

aws sns subscribe --topic-arn "$topic_arn" --protocol sqs --notification-endpoint "$queue_arn_value" \
    --attributes RawMessageDelivery=true > /dev/null
raw="$(
    aws sns list-subscriptions-by-topic --topic-arn "$topic_arn" \
        --query "Subscriptions[?Endpoint=='$queue_arn_value'].SubscriptionArn | [0]" --output text \
    | xargs -I{} aws sns get-subscription-attributes --subscription-arn {} \
        --query "Attributes.RawMessageDelivery" --output text
)"
test "$raw" = "true"

echo "Ready: $analytics_queue is subscribed to waste_obligations_analytics_events, with ${analytics_queue}-deadletter"

# The FIFO command queue and its dead-letter queue.
command_dead_letter_url="$(
    aws sqs create-queue --queue-name "$command_dead_letter_queue" --attributes FifoQueue=true \
        --query QueueUrl --output text
)"
command_url="$(
    aws sqs create-queue --queue-name "$command_queue" \
        --attributes FifoQueue=true,ContentBasedDeduplication=false,VisibilityTimeout=120 \
        --query QueueUrl --output text
)"
redrive_to "$command_url" "$(queue_arn "$command_dead_letter_url")"

echo "Ready: $command_queue, with $command_dead_letter_queue"
