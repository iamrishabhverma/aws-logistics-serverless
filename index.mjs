import axios from 'axios';

export const handler = async (event) => {
    const trackingId = event.sessionState.intent.slots.trackingId.value.originalValue;
    const url = "https://raw.githubusercontent.com/iamrishabhverma/aws-logistics-serverless/main/legacy-app/shipments.json";  // Update if needed

    try {
        const response = await axios.get(url);
        const shipments = response.data;
        const shipment = shipments.find(s => s.trackingId === trackingId);

        if (shipment) {
            return {
                sessionState: {
                    dialogAction: { type: "Close" },
                    intent: {
                        name: event.sessionState.intent.name,
                        state: "Fulfilled"
                    }
                },
                messages: [
                    {
                        contentType: "PlainText",
                        content: `Shipment ${shipment.trackingId} is ${shipment.status}. Origin: ${shipment.origin} → Destination: ${shipment.destination}. Created on ${shipment.createdAt}.`
                    }
                ]
            };
        } else {
            return {
                sessionState: {
                    dialogAction: { type: "Close" },
                    intent: {
                        name: event.sessionState.intent.name,
                        state: "Fulfilled"
                    }
                },
                messages: [
                    {
                        contentType: "PlainText",
                        content: `I couldn’t find shipment ${trackingId}. Please check the ID and try again.`
                    }
                ]
            };
        }
    } catch (error) {
        console.error('Error fetching or processing data:', error);
        return {
            sessionState: {
                dialogAction: { type: "Close" },
                intent: {
                    name: event.sessionState.intent.name,
                    state: "Failed"
                }
            },
            messages: [
                {
                    contentType: "PlainText",
                    content: "Sorry, there was an error retrieving shipment details. Please try again later."
                }
            ]
        };
    }
};
