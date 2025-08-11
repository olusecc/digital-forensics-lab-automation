#!/usr/bin/env python3
import json
import sys
import requests
from datetime import datetime

def send_slack_notification(webhook_url, status, message, investigator):
    """Send notification to Slack"""
    color = "good" if status == "SUCCESS" else "danger"
    
    payload = {
        "attachments": [
            {
                "color": color,
                "title": f"Forensics Lab Alert - {status}",
                "text": message,
                "fields": [
                    {
                        "title": "Investigator",
                        "value": investigator,
                        "short": True
                    },
                    {
                        "title": "Time",
                        "value": datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                        "short": True
                    }
                ],
                "footer": "Digital Forensics Lab",
                "ts": int(datetime.now().timestamp())
            }
        ]
    }
    
    try:
        response = requests.post(webhook_url, json=payload)
        return response.status_code == 200
    except Exception as e:
        print(f"Error sending Slack notification: {e}")
        return False

def send_email_notification(smtp_server, smtp_port, username, password, 
                          to_email, status, message, investigator):
    """Send email notification"""
    import smtplib
    from email.mime.text import MimeText
    from email.mime.multipart import MimeMultipart
    
    subject = f"Forensics Lab Alert - {status}"
    
    body = f"""
Digital Forensics Lab Notification

Status: {status}
Message: {message}
Investigator: {investigator}
Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

This is an automated notification from the Digital Forensics Lab.
"""
    
    try:
        msg = MimeMultipart()
        msg['From'] = username
        msg['To'] = to_email
        msg['Subject'] = subject
        msg.attach(MimeText(body, 'plain'))
        
        server = smtplib.SMTP(smtp_server, smtp_port)
        server.starttls()
        server.login(username, password)
        server.send_message(msg)
        server.quit()
        return True
    except Exception as e:
        print(f"Error sending email notification: {e}")
        return False

def main():
    if len(sys.argv) != 4:
        print("Usage: send_notification.py <status> <message> <investigator>")
        sys.exit(1)
    
    status = sys.argv[1]
    message = sys.argv[2]
    investigator = sys.argv[3]
    
    # Configuration - these would typically come from environment variables
    slack_webhook = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
    
    # Try to send Slack notification
    slack_sent = send_slack_notification(slack_webhook, status, message, investigator)
    
    if slack_sent:
        print("Slack notification sent successfully")
    else:
        print("Failed to send Slack notification")
    
    # Log notification locally
    log_entry = {
        'timestamp': datetime.now().isoformat(),
        'status': status,
        'message': message,
        'investigator': investigator,
        'notification_sent': slack_sent
    }
    
    with open('/var/log/forensics/notifications.log', 'a') as f:
        f.write(json.dumps(log_entry) + '\n')

if __name__ == '__main__':
    main()