import json
import os
import sys
from datetime import datetime
from os import listdir
from os.path import join

import dropbox
from dotenv import load_dotenv, dotenv_values
from dropbox.exceptions import ApiError
from dropbox.files import WriteMode

load_dotenv()
config = dotenv_values(".env")


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

    with open('dropbox_token.json', 'r') as f:
        data = json.load(f)

    data['oauth2_access_token_expiration'] = datetime.fromtimestamp(data['oauth2_access_token_expiration'])

    with dropbox.Dropbox(**data) as dbx:

        # Create a backup of the current settings file
        folder = 'files'
        for f in listdir('files'):
            backup(folder, f, delete_file=True)

        print('Done!')
