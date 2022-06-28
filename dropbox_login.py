import json
from datetime import datetime

from dropbox import DropboxOAuth2FlowNoRedirect

'''
It goes through an example of requesting a starting scope,
and requesting more throughout the process
'''
from dotenv import load_dotenv, dotenv_values

load_dotenv()
config = dotenv_values(".env")

DROPBOX_APP_KEY = config["DROPBOX_APP_KEY"]
DROPBOX_APP_SECRET = config["DROPBOX_APP_SECRET"]

auth_flow = DropboxOAuth2FlowNoRedirect(DROPBOX_APP_KEY,
                                        consumer_secret=DROPBOX_APP_SECRET,
                                        token_access_type='offline',
                                        scope=['files.metadata.read', 'files.metadata.write', 'files.content.read',
                                               'files.content.write'])

authorize_url = auth_flow.start()
print("1. Go to: " + authorize_url)
print("2. Click \"Allow\" (you might have to log in first).")
print("3. Copy the authorization code.")
auth_code = input("Enter the authorization code here: ").strip()

try:
    oauth_result = auth_flow.finish(auth_code)
    #     oauth_result = auth_flow.finish(auth_code)
    print(oauth_result)
    # save to json file
    with open('dropbox_token.json', 'w') as f:

        output = {
            'oauth2_access_token_expiration': datetime.timestamp(oauth_result.expires_at),
            'oauth2_refresh_token': oauth_result.refresh_token,
            'scope': oauth_result.scope.split(' '),
            'oauth2_access_token': oauth_result.access_token,
            'app_key': DROPBOX_APP_KEY,
            'app_secret': DROPBOX_APP_SECRET

        }
        json.dump(output, f, indent=4, sort_keys=True, default=str)
        print("Token saved to dropbox_token.json")
        print(output)

except Exception as e:
    print('Error: %s' % (e,))
    exit(1)
