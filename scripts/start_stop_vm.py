import sys
import json
import logging
import os
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail
# ------------------- Logging ------------------- #
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
# ------------------- Azure Setup ------------------- #
subscription_id = ""
credential = DefaultAzureCredential()
compute_client = ComputeManagementClient(credential, subscription_id)
# ------------------- VM Functions ------------------- #
def start_stop_vm(action, resource_group_name, vm_name):
    try:
        if action == "stop":
            logging.info(f"Stopping VM: {vm_name}")
            compute_client.virtual_machines.begin_deallocate(resource_group_name, vm_name)
        elif action == "start":
            logging.info(f"Starting VM: {vm_name}")
            compute_client.virtual_machines.begin_start(resource_group_name, vm_name)
        else:
            logging.error(f"Invalid action '{action}'")
    except Exception as e:
        logging.warning(f"VM '{vm_name}' action '{action}' failed: {e}")
# ------------------- Email Function ------------------- #
def send_email(api_token, from_email, to_emails, subject, html_content):
    if not api_token:
        logging.warning("SendGrid API key missing. Skipping email.")
        return
    message = Mail(from_email=from_email, to_emails=to_emails, subject=subject, html_content=html_content)
    try:
        sg = SendGridAPIClient(api_token)
        response = sg.send(message)
        logging.info(f"Email sent. Status: {response.status_code}")
    except Exception as e:
        logging.error(f"Failed to send email: {e}")
# ------------------- Main ------------------- #
def main(vm_details, action, send_email_flag):
    sendGridAPIKey = os.environ.get("SendGridKey")
    for vm in vm_details:
        start_stop_vm(action, vm["resource_group"], vm["name"])
    if send_email_flag:
        subject = f"{action.capitalize()}ed PowerBI VMs"
        email_content = f"""
<p>Hello,</p>
<p>The PowerBI and Tableau VMs have been {action}ed as per schedule.</p>
<ul>
        {''.join([f'<li>{vm["name"]}</li>' for vm in vm_details])}
</ul>
<p>Regards,<br>Platform Team</p>
        """
        send_email(sendGridAPIKey, "no-reply@carmax.com", ["9511209@carmax.com"], subject, email_content)
# ------------------- CLI ------------------- #
if __name__ == "__main__":
    if len(sys.argv) < 4:
        logging.error("Usage: python start_stop_vm.py '<vm_details>' <action> <sendEmail>")
        sys.exit(1)
    try:
        vm_details_str = sys.argv[1]
        action = sys.argv[2].lower()
        send_email_str = sys.argv[3]
        vm_details = json.loads(vm_details_str)
        if action not in ['start', 'stop']:
            raise ValueError("Action must be 'start' or 'stop'")
        send_email_flag = send_email_str.lower() == 'true'
        main(vm_details, action, send_email_flag)
    except ValueError as e:
        logging.error(f"Error: {e}")
        sys.exit(1)
    except json.JSONDecodeError:
        logging.error("Error: vm_details must be a valid JSON string")
        sys.exit(1)
