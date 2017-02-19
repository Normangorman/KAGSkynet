from twilio.rest import TwilioRestClient
import os
import sys

# See secrets.sh (not in git) for these values
try:
    sms_account_sid = os.environ["SMS_ACCOUNT_SID"]
    sms_auth_token = os.environ["SMS_AUTH_TOKEN"]
    sms_to_number = os.environ["SMS_TO_NUMBER"]
    sms_twilio_number = os.environ["SMS_TWILIO_NUMBER"]
except KeyError as e:
    print("sms.py missing required environment variable")
    print(e)
    sys.exit(1)

def send_sms(msg):
    client = TwilioRestClient(sms_account_sid, sms_auth_token)

    message = client.messages.create(body="Hello from Python",
        to=sms_to_number,
        from_=sms_twilio_number
        )

    return message.sid
