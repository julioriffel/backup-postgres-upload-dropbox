import os
import sys
from os import listdir
from os.path import join

import dropbox
from dropbox.exceptions import ApiError, AuthError
from dropbox.files import WriteMode

from dotenv import load_dotenv, dotenv_values

load_dotenv()
config = dotenv_values(".env")
DROPBOX_TOKEN = config["DROPBOX_TOKEN"]


# Uploads contents of LOCALFILE to Dropbox
def backup(folder, filename, delete_file=False):
    LOCALFILE = join(folder, filename)
    BACKUPPATH = f'/{filename}'
    sucess = False

    with open(LOCALFILE, 'rb') as f:
        # We use WriteMode=overwrite to make sure that the settings in the file
        # are changed on upload
        print('Uploading ' + LOCALFILE + ' to Dropbox as ' + BACKUPPATH + '...')
        try:
            dbx.files_upload(f.read(), BACKUPPATH, mode=WriteMode('overwrite'))
            sucess = True
        except ApiError as err:
            # This checks for the specific error where a user doesn't have
            # enough Dropbox space quota to upload this file
            if err.error.is_path() and err.error.get_path().reason.is_insufficient_space():
                sys.exit('ERROR: Cannot back up; insufficient space.')
            elif err.user_message_text:
                print(err.user_message_text)
                sys.exit()
            else:
                print(err)
                sys.exit()

    if delete_file and sucess:
        os.remove(LOCALFILE)


if __name__ == '__main__':
    # Check for an access token
    if len(DROPBOX_TOKEN) == 0:
        sys.exit(
            "ERROR: Looks like you didn't add your access token. "
            'Open up backup-and-restore-example.py in a text editor and '
            'paste in your token in line 14.'
        )

    # Create an instance of a Dropbox class, which can make requests to the API.
    print('Creating a Dropbox object...')
    with dropbox.Dropbox(DROPBOX_TOKEN) as dbx:

        # Check that the access token is valid
        try:
            dbx.users_get_current_account()
        except AuthError:
            sys.exit(
                'ERROR: Invalid access token; try re-generating an ' 'access token from the app console on the web.'
            )

        # Create a backup of the current settings file
        folder = 'files'
        for f in listdir('files'):
            backup(folder, f, delete_file=True)

        print('Done!')
